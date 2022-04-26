import XCTest
@testable import ERBufferedStream
import OpenCombineDispatch
import OpenCombine
import Combine

final class ERBufferedStreamTests: XCTestCase {
    var cancellables = Set<Combine.AnyCancellable>()
    
    func testStream() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        
        struct StreamPayload: Codable {
            var field1: String
            var field2: Int
            var field3: Bool
            
            init() {
                field1 = "abcdefghijklmnopqrstuvwxyz"
                field2 = .max
                field3 = true
            }
            
            var count: Int {
                (try! JSONEncoder().encode(self)).count
            }
        }
        
        let stream = ERBufferedStream<StreamPayload>()
        
        var count = 0
        
        var windowMultipliers: [Double] = []
        for i in 0..<20 {
            var offset = 0.0
            for _ in 0..<20 {
                windowMultipliers.append(Double(i) + offset)
                offset += 0.05
            }
        }
        print(windowMultipliers)
        
        let cancellable = stream.subject.sink { payload in
            if case .failure(let error) = payload {
                XCTFail("Encountered an error during stream smoke test: \(error)")
            }
            print("A payload!")
            count += 1
        }
        unsafeBitCast(cancellable, to: Combine.AnyCancellable.self).store(in: &cancellables)
        print(cancellables)
        
        let payload = StreamPayload()
        let data = try! JSONEncoder().encode(payload)
        let payloads = (0..<250).reduce(into: Data()) { dataCollector, _ in
            dataCollector += (data + Data([10]))
        }
        
        for windowMultiplier in windowMultipliers {
            let windowCount = max(Int(Double(data.count) * windowMultiplier), 1)
            count = 0
            stream.clear()
            
            for start in stride(from: payloads.startIndex, to: payloads.endIndex, by: windowCount) {
                let stop = min(start + (windowCount - 1), payloads.count - 1)
                stream.receive(data: payloads[start...stop])
            }
            
            XCTAssert(count == 250, "Data integrity: Sent 250 payloads but got \(count) back")
        }
    }
}
