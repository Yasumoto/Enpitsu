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
    let metrics_index = "/metrics/index.json"
    let session = URLSession(configuration: URLSessionConfiguration.default)
    let graphiteDateFormatter = DateFormatter()

    public init(graphiteServer: String, query: String? = nil, authHeader: (String, String)? = nil) {
        graphiteDateFormatter.dateFormat = "HH:mm_yyyyMMdd"
        self.graphiteServer = graphiteServer
        self.query = query ?? "/render?format=json&target="
        self.authHeader = authHeader
    }

    private func createURL(metric: String, from: String, until: String) throws -> URL {
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

    public func retrieveMetrics(_ metric: String, from: GraphiteDate = .string("-10min"), until: GraphiteDate = .string("now")) throws -> [Timeseries] {
        let sema = DispatchSemaphore(value: 0)
        var series = [Timeseries]()
        let serverUrl = try createURL(metric: metric, from: formatDate(from), until: formatDate(until))
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
