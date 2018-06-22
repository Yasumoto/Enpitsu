import Dispatch
import Foundation

public struct Enpitsu {
    enum GraphiteError: Swift.Error {
        case queryStringFormattingError
        case urlFormattingError
    }

    public enum GraphiteDate {
        case string(String)
        case date(Date)
    }

    public struct DashboardResponse: Decodable {
        public struct Meta: Decodable {
            let type: String
            let createdBy: String
            let updatedBy: String
            let version: Int
            let slug: String
            let url: String
        }

        let dashboard: Dashboard
        let meta: Meta
    }

    public struct Dashboard: Decodable {
        public struct Panel: Decodable {
            public enum PanelType: String, Decodable {
                case row, graph
            }

            public struct Target: Decodable {
                let type: String?
                let query: String?
                let target: String?
                let expr: String? // The important part!
            }

            let type: PanelType
            let description: String?
            //TODO: let thresholds =
            let title: String
            let targets: [Target]?
        }

        let id: Int
        let uid: String
        let title: String
        let url: String?
        let type: String?
        let tags: [String]
        let isStarred: Bool?
        let panels: [Panel]?
    }

    public struct Timeseries: Decodable {
        public struct Datapoint: Decodable {
            public let date: Date
            public let value: Double?

            public init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                value = try container.decodeIfPresent(Double.self)
                let timestamp = try container.decode(Int.self)
                date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
        }

        public let target: String
        public let datapoints: [Datapoint]
    }

    let graphiteServer: String
    let query: String
    let authHeader: (String, String)?
    let session = URLSession(configuration: URLSessionConfiguration.default)
    let graphiteDateFormatter = DateFormatter()

    public init(graphiteServer: String, query: String? = nil, authHeader: (String, String)? = nil) {
        graphiteDateFormatter.dateFormat = "HH:mm_yyyyMMdd"
        self.graphiteServer = graphiteServer
        self.query = query ?? "/render?format=json&target="
        self.authHeader = authHeader
    }

    /**

     Generate a url for metrics

     - parameter metric: Query to retrieve data from Graphite
     - parameter from: Starting point. Graphite parses a specific date format as well as a host of relative times
     - parameter until: Last metric to gather. Follows same format as above

     - returns: Valid URL to query Graphite
    */
    private func createMetricsURL(metric: String, from: String, until: String) throws -> URL {
        guard let endpoint = "\(query)\(metric)&from=\(from)&until=\(until)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw GraphiteError.queryStringFormattingError
        }
        guard let serverUrl = URL(string: "\(graphiteServer)\(endpoint)") else {
            throw GraphiteError.urlFormattingError
        }
        return serverUrl
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
    public func getDashboard(_ uid: String) throws -> DashboardResponse? {
        let sema = DispatchSemaphore(value: 0)
        var dashboard: DashboardResponse? = nil
        guard let endpoint = "\(uid)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw GraphiteError.queryStringFormattingError
        }
        guard let serverUrl = URL(string: "\(graphiteServer)/api/dashboards/uid/\(endpoint)") else {
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
                    dashboard = try JSONDecoder().decode(DashboardResponse.self, from: data)
                } catch {
                    print("Problem parsing JSON: \(error)")
                }
            }
            sema.signal()
        }
        task.resume()
        sema.wait()
        return dashboard
    }

    /**

     Search Grafana for dashboards matching a name string

     - parameter query: Find graphs matching this name saved in Grafana

     - returns: List of matching Dashboards
     */
    public func searchDashboards(_ query: String) throws -> [Dashboard] {
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
    }

    /**

     Query Graphite for a set of metrics given a query and timebox

     - parameter metric: Query to retrieve data from Graphite
     - parameter from: Starting point. Graphite parses a specific date format as well as a host of relative times
     - parameter until: Last metric to gather. Follows same format as above

     - returns: Timeseries data
     */
    public func retrieveMetrics(_ metric: String, from: GraphiteDate = .string("-10min"), until: GraphiteDate = .string("now")) throws -> [Timeseries] {
        let sema = DispatchSemaphore(value: 0)
        var series = [Timeseries]()
        let serverUrl = try createMetricsURL(metric: metric, from: formatDate(from), until: formatDate(until))
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
                    series = try JSONDecoder().decode([Timeseries].self, from: data)
                } catch {
                    print("Problem parsing JSON: \(error)")
                }
            }
            sema.signal()
        }
        task.resume()
        sema.wait()
        return series
    }
}
