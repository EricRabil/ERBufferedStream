import Foundation
import OpenCombine

/// A data reader that reads from an infinite data stream and emits some Decodable type whenever the current piece of data becomes decodable.
public class ERBufferedStream<Payload: Decodable> {
    public struct StreamError: Error {
        public var error: Error
        public var rawData: Data
    }
    
    /// The byte that splits one chunk of data from the next.
    public let terminator: UInt8
    
    public init(terminator: UInt8) {
        self.terminator = terminator
    }
    
    public convenience init() {
        self.init(terminator: 10)
    }
    
    /// The subject where decoded data (or an error) is emitted as it is processed
    public let subject = PassthroughSubject<Payload, StreamError>()
    
    private var buffer = Data()
    private let queue = DispatchQueue(label: "ERBufferedStream")
    
    /// Attempts to decode and emit the current buffer
    private func sendBuffer() {
        let data = buffer
        buffer = Data()
        do {
            subject.send(try JSONDecoder().decode(Payload.self, from: data))
        } catch {
            subject.send(completion: .failure(StreamError(error: error, rawData: data)))
        }
    }
    
    public func receive(data: Data) {
        queue.sync {
            guard !data.isEmpty else {
                return
            }
            
            var data = data
            // Scan for terminators
            while let terminatorIndex = data.firstIndex(of: terminator) {
                // push the remaining data
                buffer.append(data[...terminatorIndex])
                // send it
                sendBuffer()
                if terminatorIndex < (data.index(before: data.endIndex)) {
                    // more data to read!
                    data = data[data.index(after: terminatorIndex)...]
                } else {
                    // all done, do not append data to buffer
                    return
                }
            }
            buffer.append(data)
        }
    }
    
    /// Empties the internal data buffer
    public func clear() {
        queue.sync {
            buffer = Data()
        }
    }
}
