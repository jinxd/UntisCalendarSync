import Foundation

actor UntisService {
    static let shared = UntisService()

    private var sessionId: String?
    private var personId: Int?
    private var personType: Int?
    private var baseURL: URL = URL(string: "https://mgg-horb.webuntis.com")!

    private let urlSession: URLSession
    private let cookieStorage: HTTPCookieStorage

    private init() {
        let config = URLSessionConfiguration.ephemeral
        // Let URLSession manage all cookies automatically via its in-memory jar.
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        urlSession = URLSession(configuration: config)
        // ephemeral always has a non-nil in-memory storage
        cookieStorage = config.httpCookieStorage!
    }

    // MARK: - Authentication

    func authenticate(with credentials: UntisCredentials) async throws {
        baseURL = credentials.baseURL
        sessionId = nil
        personId = nil
        personType = nil

        // Wipe any cookies from a previous session.
        cookieStorage.cookies?.forEach { cookieStorage.deleteCookie($0) }

        // Inject the schoolname cookie so classreg APIs can resolve the tenant.
        // For single-school installs (e.g. mgg-horb.webuntis.com) the school name
        // is the first component of the hostname.
        let host = baseURL.host ?? ""
        if let school = host.components(separatedBy: ".").first, !school.isEmpty {
            injectCookie(name: "schoolname", value: school)
        }

        // Hit the landing page so Spring Security can set the XSRF-TOKEN cookie
        // it will later require on every mutating request.
        _ = try? await urlSession.data(from: baseURL.appendingPathComponent("WebUntis/index.do"))

        // JSON-RPC authenticate — gives us the session ID + person info.
        let payload: [String: Any] = [
            "id": "1",
            "jsonrpc": "2.0",
            "method": "authenticate",
            "params": [
                "user": credentials.username,
                "password": credentials.password,
                "client": "UntisCalendarSync"
            ]
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("WebUntis/jsonrpc.do"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await urlSession.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UntisError.invalidResponse
        }
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw UntisError.serverError(message)
        }
        guard let result = json["result"] as? [String: Any],
              let sid = result["sessionId"] as? String, !sid.isEmpty else {
            throw UntisError.authenticationFailed
        }

        sessionId  = sid
        personId   = result["personId"]   as? Int
        personType = result["personType"] as? Int

        // Ensure JSESSIONID is in the cookie jar even if the JSON-RPC response
        // only returned it in the body (some installs skip the Set-Cookie header).
        injectCookie(name: "JSESSIONID", value: sid)
    }

    // MARK: - Timetable

    func fetchLessons(weekOffset: Int) async throws -> [Lesson] {
        guard let sessionId, let personId, let personType else {
            throw UntisError.notAuthenticated
        }

        let monday = weekStart(offset: weekOffset)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: monday)

        var components = URLComponents(
            url: baseURL.appendingPathComponent("WebUntis/api/public/timetable/weekly/data"),
            resolvingAgainstBaseURL: true
        )!
        components.queryItems = [
            URLQueryItem(name: "elementType", value: "\(personType)"),
            URLQueryItem(name: "elementId",   value: "\(personId)"),
            URLQueryItem(name: "date",        value: dateString),
            URLQueryItem(name: "formatId",    value: "1")
        ]
        guard let url = components.url else { throw UntisError.invalidURL }

        let (data, _) = try await urlSession.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj   = json["data"]   as? [String: Any],
              let resultObj = dataObj["result"] as? [String: Any],
              let timetable = resultObj["data"]  as? [String: Any] else {
            return []
        }

        let elementPeriods = timetable["elementPeriods"] as? [String: Any] ?? [:]
        let elements       = timetable["elements"]       as? [[String: Any]] ?? []

        var elemMap: [String: [String: Any]] = [:]
        for elem in elements {
            if let type = elem["type"] as? Int, let id = elem["id"] as? Int {
                elemMap["\(type):\(id)"] = elem
            }
        }

        func lookupName(type: Int, id: Int) -> String {
            let e = elemMap["\(type):\(id)"] ?? [:]
            return (e["displayname"] as? String) ?? (e["name"] as? String) ?? "\(id)"
        }

        let periods = elementPeriods["\(personId)"] as? [[String: Any]] ?? []
        return periods.compactMap { parsePeriod($0, lookupName: lookupName) }
    }


    // MARK: - All lessons

    func fetchAllLessons() async throws -> [Lesson] {
        var allLessons: [Lesson] = []
        var consecutiveEmpty = 0
        var offset = -1

        while offset <= 52 {
            let lessons = try await fetchLessons(weekOffset: offset)
            if lessons.isEmpty {
                consecutiveEmpty += 1
                if consecutiveEmpty >= 3 && offset > 4 { break }
            } else {
                consecutiveEmpty = 0
                allLessons.append(contentsOf: lessons)
            }
            offset += 1
        }

        return allLessons
    }

    // MARK: - Holidays

    func fetchHolidays() async throws -> [Holiday] {
        guard sessionId != nil else { throw UntisError.notAuthenticated }

        let payload: [String: Any] = [
            "id": "1",
            "jsonrpc": "2.0",
            "method": "getHolidays",
            "params": [String: Any]()
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("WebUntis/jsonrpc.do"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await urlSession.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [[String: Any]] else {
            return []
        }

        return result.compactMap { h -> Holiday? in
            guard let id       = h["id"]        as? Int,
                  let startInt = h["startDate"]  as? Int,
                  let endInt   = h["endDate"]    as? Int else { return nil }
            let name = (h["longName"] as? String) ?? (h["name"] as? String) ?? "Holiday"
            return Holiday(id: id, name: name, startDate: untisDate(startInt), endDate: untisDate(endInt))
        }
    }

    // MARK: - Private helpers

    private func injectCookie(name: String, value: String) {
        guard let cookie = HTTPCookie(properties: [
            .name:    name,
            .value:   value,
            .domain:  baseURL.host ?? "",
            .path:    "/"
        ]) else { return }
        cookieStorage.setCookie(cookie)
    }

    private func parsePeriod(_ p: [String: Any], lookupName: (Int, Int) -> String) -> Lesson? {
        guard let id           = p["id"]        as? Int,
              let dateInt      = p["date"]       as? Int,
              let startTimeInt = p["startTime"]  as? Int,
              let endTimeInt   = p["endTime"]    as? Int else { return nil }

        let startDate = untisDateTime(date: dateInt, time: startTimeInt)
        let endDate   = untisDateTime(date: dateInt, time: endTimeInt)
        let dayDate   = untisDate(dateInt)

        let elems = p["elements"] as? [[String: Any]] ?? []
        let subjects = elems.filter { ($0["type"] as? Int) == 3 }.compactMap { $0["id"] as? Int }.map { lookupName(3, $0) }
        let teachers = elems.filter { ($0["type"] as? Int) == 2 }.compactMap { $0["id"] as? Int }.map { lookupName(2, $0) }
        let rooms    = elems.filter { ($0["type"] as? Int) == 4 }.compactMap { $0["id"] as? Int }.map { lookupName(4, $0) }

        let lessonCode = p["lessonCode"] as? String ?? ""
        let cellState  = p["cellState"]  as? String ?? ""

        let status: LessonStatus
        switch (lessonCode, cellState) {
        case ("CANCELLED", _), (_, "CANCEL"): status = .cancelled
        case ("SUBSTITUTION", _):             status = .substitution
        case ("UNTIS_EXAM_2016", _):          status = .exam
        case ("UNTIS_ADDITIONAL", _):         status = .additional
        default:                              status = .normal
        }

        let notes = (p["lessonText"] as? String) ?? (p["periodText"] as? String) ?? ""

        return Lesson(
            id: id,
            date: dayDate,
            startDate: startDate,
            endDate: endDate,
            subjects: subjects,
            teachers: teachers,
            rooms: rooms,
            status: status,
            notes: notes
        )
    }

    private func weekStart(offset: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "de_DE")
        let today = Date()
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2
        let monday = cal.date(from: comps) ?? today
        return cal.date(byAdding: .weekOfYear, value: offset, to: monday) ?? monday
    }

    private func untisDate(_ dateInt: Int) -> Date {
        let s = String(format: "%08d", dateInt)
        var comps = DateComponents()
        comps.year  = Int(s.prefix(4))
        comps.month = Int(s.dropFirst(4).prefix(2))
        comps.day   = Int(s.dropFirst(6))
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func untisDateTime(date dateInt: Int, time timeInt: Int) -> Date {
        let ds = String(format: "%08d", dateInt)
        let ts = String(format: "%04d", timeInt)
        var comps = DateComponents()
        comps.year   = Int(ds.prefix(4))
        comps.month  = Int(ds.dropFirst(4).prefix(2))
        comps.day    = Int(ds.dropFirst(6))
        comps.hour   = Int(ts.prefix(2))
        comps.minute = Int(ts.suffix(2))
        return Calendar.current.date(from: comps) ?? Date()
    }
}

enum UntisError: LocalizedError {
    case authenticationFailed
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:   return "Login failed. Check your username and password."
        case .notAuthenticated:       return "Not authenticated. Please log in first."
        case .invalidURL:             return "Invalid server URL."
        case .invalidResponse:        return "Unexpected response from server."
        case .serverError(let msg):   return "Server error: \(msg)"
        }
    }
}
