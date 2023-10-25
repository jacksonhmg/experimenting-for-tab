import Foundation
import UserNotifications
import UIKit


class NotificationBanner: UIView {

    private let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        return label
    }()

    init(message: String) {
        super.init(frame: CGRect(x: 0, y: -60, width: UIScreen.main.bounds.width, height: 60))
        backgroundColor = UIColor.red
        label.text = message

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(on view: UIView) {
        view.addSubview(self)
        UIView.animate(withDuration: 0.5, animations: {
            self.frame.origin.y = 0
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.hide()
            }
        }
    }

    func hide() {
        UIView.animate(withDuration: 0.5, animations: {
            self.frame.origin.y = -60
        }) { _ in
            self.removeFromSuperview()
        }
    }
}




// MARK: - LocalTranscriptionError

enum LocalTranscriptionError: Error {
  case notEnoughMemory(available: UInt64, required: UInt64)
}

// MARK: - LocalTranscriptionWorkExecutor

final class LocalTranscriptionWorkExecutor: TranscriptionWorkExecutor {
  var currentWhisperContext: (context: WhisperContextProtocol, modelType: VoiceModelType)? = nil

  private let updateTranscription: (_ transcription: Transcription) -> Void

  init(updateTranscription: @escaping (_ transcription: Transcription) -> Void) {
    self.updateTranscription = updateTranscription
  }
  
  func loadEnvironmentKeys() -> [String: String] {
      guard let filePath = Bundle.main.path(forResource: ".env", ofType: nil) else {
          fatalError("Couldn't find file '.env'")
      }
      
      let keys: [String: String]
      do {
          let contents = try String(contentsOfFile: filePath)
          keys = contents
              .split(separator: "\n")
              .map(String.init)
              .filter { !$0.hasPrefix("#") && !$0.isEmpty }
              .reduce(into: [String: String]()) { (result, keyValueString) in
                  let keyValueArray = keyValueString.split(separator: "=", maxSplits: 1)
                  if keyValueArray.count == 2 {
                      result[String(keyValueArray[0])] = String(keyValueArray[1])
                  }
              }
      } catch {
          fatalError("Error loading .env - \(error.localizedDescription)")
      }
      
      return keys
  }
  
  func sendTranscriptToGPT(transcript: String, completion: @escaping (Result<String, Error>) -> Void) {
      // Define API URL and request headers
    //let envKeys = loadEnvironmentKeys()
    //let apiKey = envKeys["OPENAI_API_KEY"]

    let openAIApiURL = URL(string: "https://api.openai.com/v1/chat/completions")!
      var request = URLRequest(url: openAIApiURL)
      request.httpMethod = "POST"
      request.addValue("Bearer ", forHTTPHeaderField: "Authorization")
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")

      // Define your prompt
    let prompt: [String: Any] = [
        "model": "gpt-3.5-turbo",
        "messages": [
            ["role": "system", "content": "You are tasked with extracting tasks from conversation. You need to respond with helpful questions, advice, help based on large transcriptions you are fed. If there is nothing actionable the user needs help with, do not provide anything"],
            ["role": "user", "content": "I really need to go grocery shopping tomorrow, I'm not sure how I'll get there. How has your day been? Man that's really cool, I miss Florida hey. Yeah I should come soon."],
            ["role": "assistant", "content": "Do you want to set a reminder to get groceries?"],
            ["role": "user", "content": "Yeah I'd love to learn more about quantum computing, I just always forget. Do you have any book recommendations? Oh that's awesome, yeah I'll check that out."],
            ["role": "assistant", "content": "Would you like to learn more about quantum computing?"],
            ["role": "user", "content": "Wow that's a lovely painting, where did you get it? Seems gorgeous, it must've cost a fortune aye? Wow yeah that's crazy"],
            ["role": "assistant", "content": "-"],
            ["role": "user", "content": "That's so interesting, how did you learn about that? What's it called? wikipedia.com? Oh okay wow, I really need to check out that site thank you."],
            ["role": "assistant", "content": "Do you want to check out wikipedia.com?"],
            ["role": "user", "content": transcript]
        ]
    ]


    
      // Convert prompt to JSON data
      let jsonData = try? JSONSerialization.data(withJSONObject: prompt)

      request.httpBody = jsonData

      // Create a task to perform the API call
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        
        if let data = data {
            // Print the raw response data here
            print(String(data: data, encoding: .utf8) ?? "Invalid data")
            
            if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let messageContent = jsonResponse["choices"] as? [[String: Any]], let firstChoice = messageContent.first,
               let message = firstChoice["message"] as? [String: String], let content = message["content"] {
                DispatchQueue.main.async {
                    completion(.success(content))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "com.example.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse API response"])))
                }
            }
        }
    }


      // Start the task
      task.resume()
  }



  func processTask(_ task: TranscriptionTask, updateTask: @escaping (TranscriptionTask) -> Void) async {
    var task: TranscriptionTask = task {
      didSet { updateTask(task) }
    }
    var transcription = Transcription(id: task.id, fileName: task.fileName, parameters: task.parameters, model: task.modelType) {
      didSet { updateTranscription(transcription) }
    }

    do {
      transcription.status = .loading

      let context: WhisperContextProtocol = try await resolveContextFor(task: task) { task = $0 }
      let samples = try decodeWaveFile(task.fileURL)

      transcription.status = .progress(0.0)

      for await action in try await context.fullTranscribe(samples: samples, params: task.parameters) {
        log.debug(action)
        switch action {
        case let .newSegment(segment):
          transcription.segments.append(segment)
        case let .progress(progress):
          transcription.status = .progress(progress)
        case let .error(error):
          transcription.status = .error(message: error.localizedDescription)
        case .canceled:
          transcription.status = .canceled
        case let .finished(segments):
          transcription.segments = segments
          transcription.status = .done(Date())
          sendTranscriptToGPT(transcript: transcription.text) { result in
              switch result {
              case .success(let content):
                  print("Received response: \(content)")
                DispatchQueue.main.async {
                  
                  if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                     let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    let banner = NotificationBanner(message: content)
                    banner.show(on: keyWindow)
                  }
                }

              case .failure(let error):
                  print("Error occurred: \(error.localizedDescription)")
                  // Handle the error, show error message to user, etc.
              }
          }
        }
      }
    } catch {
      transcription.status = .error(message: error.localizedDescription)
    }
  }

  func cancel(task _: TranscriptionTask) {
    currentWhisperContext?.context.cancel()
  }

  private func resolveContextFor(task: TranscriptionTask, updateTask: (TranscriptionTask) -> Void) async throws -> WhisperContextProtocol {
    if let currentContext = currentWhisperContext, currentContext.modelType == task.modelType {
      return currentContext.context
    } else {
      let selectedModel = FileManager.default.fileExists(atPath: task.modelType.localURL.path) ? task.modelType : .default
      // Update model type in case it of fallback to default
      updateTask(task.with(\.modelType, setTo: selectedModel))

      let memory = freeMemoryAmount()
      log.info("Available memory: \(bytesToReadableString(bytes: availableMemory()))")
      log.info("Free memory: \(bytesToReadableString(bytes: memory))")

      guard memory > selectedModel.memoryRequired else {
        throw LocalTranscriptionError.notEnoughMemory(available: memory, required: selectedModel.memoryRequired)
      }

      let context = try await WhisperContext.createFrom(modelPath: selectedModel.localURL.path)
      currentWhisperContext = (context, selectedModel)
      return context
    }
  }
}

private func decodeWaveFile(_ url: URL) throws -> [Float] {
  let data = try Data(contentsOf: url)
  let floats = stride(from: 44, to: data.count, by: 2).map {
    data[$0 ..< $0 + 2].withUnsafeBytes {
      let short = Int16(littleEndian: $0.load(as: Int16.self))
      return max(-1.0, min(Float(short) / 32767.0, 1.0))
    }
  }
  return floats
}
