import Dispatch
import Foundation

enum GraphiteError: Swift.Error {
        case urlFormattingError
}

struct Enpitsu {
    let graphiteServer: String
    let metrics_index = "/metrics/index.json"
    let query = "/render?format=json&target="
    let sema = DispatchSemaphore(value: 0)

    func retrieveMetrics(_ metric: String, from: String = "-10min", until: String = "now") -> Any? {
        var jsonOutput: Any?
        guard let endpoint = "\(query)\(metric)&from=\(from)&now=\(until)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { print("Unable to format URL!"); return jsonOutput }
        if let serverUrl = URL(string: "\(graphiteServer)\(endpoint)") {
            let session = URLSession(configuration: URLSessionConfiguration.default)
            var request = URLRequest(url: serverUrl)
            print(serverUrl)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let task = session.dataTask(with: request) {
                if let responded = $1 as? HTTPURLResponse {
                    if responded.statusCode != 200 {
                        print("The response was: \(responded)")
                    }
                }
                if let responseError = $2 {
                    print("Error: \(responseError)")
                    print("Code: \(responseError._code)")
                } else if let data = $0 {
                    do {
                        let output = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                        jsonOutput = output
                    } catch {
                        print("Warning, did not receive valid JSON!\n\(error)")
                    }
                }
                self.sema.signal()
            }
            task.resume()
            sema.wait()
        }
        return jsonOutput
    }
}
