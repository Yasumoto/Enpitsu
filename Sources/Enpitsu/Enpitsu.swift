import Foundation
import NIO
import NIOHTTPClient

public enum EnpitsuError: Error {
    case noResponseData
}

public struct Enpitsu {
    public enum GraphiteError: Swift.Error {
        case queryStringFormattingError
        case urlFormattingError
        case improperlyFormattedRequest
    }

    let graphiteServer: String
    let cookie: String?
    let userAgent: String?
    let graphiteDateFormatter = DateFormatter()
    public let client = HTTPClient(eventLoopGroupProvider: .createNew)

    public init(graphiteServer: String, query: String? = nil, cookie: String? = nil, userAgent: String? = nil) {
        graphiteDateFormatter.dateFormat = "HH:mm_yyyyMMdd"
        self.graphiteServer = graphiteServer
        self.cookie = cookie
        self.userAgent = userAgent
    }

    /**

     Generate a url for metrics

     - parameter metric: Query to retrieve data from Graphite
     - parameter from: Starting point. Graphite parses a specific date format as well as a host of relative times
     - parameter until: Last metric to gather. Follows same format as above

     - returns: Valid HTTPClient.Request to query Graphite
     */
    private func createRequest(endpoint: String) throws -> HTTPClient.Request {
        let characterSet = CharacterSet.urlQueryAllowed.subtracting(["'", ","])
        guard let endpoint = endpoint.addingPercentEncoding(withAllowedCharacters: characterSet) else {
            throw GraphiteError.queryStringFormattingError
        }

        guard let serverUrl = URL(string: "\(graphiteServer)\(endpoint)") else {
            throw GraphiteError.urlFormattingError
        }
        var request = try HTTPClient.Request(url: serverUrl)
        request.headers.add(name: "Accept", value: "application/json")
        if let cookie = cookie {
            request.headers.add(name: "Cookie", value: cookie)
        }
        if let userAgent = userAgent {
            request.headers.add(name: "User-Agent", value: userAgent)
        }

        return request
    }

    private func formatDate(_ input: GraphiteDate) -> String {
        switch input {
        case .string(let value):
            return value
        case .date(let date):
            return graphiteDateFormatter.string(from: date)
        }
    }


    /**

     Get a dashboard from Grafana

     - parameter uid: Find graphs matching this unique identifier

     - returns: The matching Dashboard
     */
    public func getDashboard(_ uid: String) -> EventLoopFuture<DashboardResponse> {
        let request: HTTPClient.Request

        do {
            request = try createRequest(endpoint: "/api/dashboards/uid/\(uid)")
        } catch {
            return self.client.eventLoopGroup.next().makeFailedFuture(error)
        }

        return client.execute(request: request).flatMapThrowing { serverResponse -> DashboardResponse in
            var response = serverResponse
            guard let count = response.body?.readableBytes, let body = response.body?.readBytes(length: count) else {
                throw EnpitsuError.noResponseData
            }
            //if let answer = String(data: Data(body), encoding: .utf8) { print("\(answer)") }
            return try JSONDecoder().decode(DashboardResponse.self, from: Data(body))
        }
    }

    /**
     Find a datasource by its name
     */
    public func getDatasource(name: String) -> EventLoopFuture<Int> {
        let request: HTTPClient.Request

        do {
            request = try createRequest(endpoint: "/api/datasources/id/\(name)")
        } catch {
            return self.client.eventLoopGroup.next().makeFailedFuture(error)
        }

        return client.execute(request: request).flatMapThrowing { serverResponse -> Int in
            struct DataSourceResponse: Decodable {
                let id: Int
            }
            var response = serverResponse
            guard let count = response.body?.readableBytes, let body = response.body?.readBytes(length: count) else {
                throw EnpitsuError.noResponseData
            }
            //if let answer = String(data: Data(body), encoding: .utf8) { print("\(answer)") }
            return try JSONDecoder().decode(DataSourceResponse.self, from: Data(body)).id
        }
    }

    /**

     Search Grafana for dashboards matching a name string

     - parameter query: Find graphs matching this name saved in Grafana

     - returns: List of matching Dashboards
     */
    /*public func searchDashboards(_ query: String) throws -> [Dashboard] {
     let sema = DispatchSemaphore(value: 0)
     var dashboards = [Dashboard]()
     guard let endpoint = "\(query)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
     throw GraphiteError.queryStringFormattingError
     }
     guard let serverUrl = URL(string: "\(graphiteServer)/api/search?query=\(endpoint)") else {
     throw GraphiteError.urlFormattingError
     }
     var request = URLRequest(url: serverUrl)
     request.setValue("application/json", forHTTPHeaderField: "Accept")
     if let authHeader = authHeader {
     request.setValue(authHeader.1, forHTTPHeaderField: authHeader.0)
     }
     let task = session.dataTask(with: request) { data, response, responseError in
     if let response = response as? HTTPURLResponse, response.statusCode != 200 {
     print("The response was: \(response)")
     }
     if let responseError = responseError {
     print("Error: \(responseError)")
     print("Code: \(responseError._code)")
     } else if let data = data {
     do {
     dashboards = try JSONDecoder().decode([Dashboard].self, from: data)
     } catch {
     print("Problem parsing JSON: \(error)")
     }
     }
     sema.signal()
     }
     task.resume()
     sema.wait()
     return dashboards
     }*/

    /**

     Query Graphite for a set of metrics given a query and timebox

     - parameter metric: Query to retrieve data from Graphite
     - parameter from: Starting point. Graphite parses a specific date format as well as a host of relative times
     - parameter until: Last metric to gather. Follows same format as above

     - returns: Timeseries data
     */
    public func retrieveMetrics(_ metric: String, datasourceID: Int, start: Date? = nil, end: Date = Date()) -> EventLoopFuture<TimeseriesResponse> {
        var start = start
        if start == nil {
            let calendar = Calendar(identifier: .gregorian)
            start = calendar.date(byAdding: .minute, value: -10, to: end)!
        }
        let request: HTTPClient.Request
        if datasourceID == 1 {
            let updatedMetric = metric.replacingOccurrences(of: "'1m'", with: "'1min'")
            do {
                request = try createRequest(endpoint: "/api/datasources/proxy/1/render?target=\(updatedMetric)&from=-10m&until=now&format=json&maxDataPoints=400")
            } catch {
                return self.client.eventLoopGroup.next().makeFailedFuture(error)
            }
        } else {
            do {
                request = try createRequest(endpoint: "/api/datasources/proxy/\(datasourceID)/api/v1/query_range?query=\(metric)&start=\(Int(start!.timeIntervalSince1970))&end=\(Int(end.timeIntervalSince1970))&step=60")
            } catch {
                return self.client.eventLoopGroup.next().makeFailedFuture(error)
            }
        }
        //print("** Request: \(request)")
        return client.execute(request: request).flatMapThrowing { serverResponse -> TimeseriesResponse in
            var response = serverResponse
            guard let count = response.body?.readableBytes, let body = response.body?.readBytes(length: count) else {
                throw EnpitsuError.noResponseData
            }
            //if let metrics = String(data: Data(body), encoding: .utf8) { print("** Metrics response:\n\(metrics)") }
            do {
                return try .prometheus(JSONDecoder().decode(PrometheusResponse.self, from: Data(body)))
            } catch {
                return try .graphite(JSONDecoder().decode([Timeseries].self, from: Data(body)))
            }
        }
    }
}
