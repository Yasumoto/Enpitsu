import Dispatch
import Foundation

public struct Enpitsu {
    enum GraphiteError: Swift.Error {
        case queryStringFormattingError
        case urlFormattingError
    }

    public struct Datapoint: Codable {
        public let date: Date
        public let value: Double?
    }

    public struct Timeseries: Codable {
        public let target: String
        public let datapoints: [Datapoint]
    }

    let graphiteServer: String
    let query: String
    let authHeader: (String, String)?
    let metrics_index = "/metrics/index.json"
    let session = URLSession(configuration: URLSessionConfiguration.default)


    public init(graphiteServer: String, query: String? = nil, authHeader: (String, String)? = nil) {
        self.graphiteServer = graphiteServer
        self.query = query ?? "/render?format=json&target="
        self.authHeader = authHeader
    }

    public func retrieveMetrics(_ metric: String, from: String = "-10min", until: String = "now") throws -> [Timeseries] {
        let sema = DispatchSemaphore(value: 0)
        var series = [Timeseries]()
        guard let endpoint = "\(query)\(metric)&from=\(from)&until=\(until)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw GraphiteError.queryStringFormattingError
        }
        guard let serverUrl = URL(string: "\(graphiteServer)\(endpoint)") else {
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
                    if let stringData = String(data: data, encoding: .utf8) {
                        print(stringData)
                    }
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
