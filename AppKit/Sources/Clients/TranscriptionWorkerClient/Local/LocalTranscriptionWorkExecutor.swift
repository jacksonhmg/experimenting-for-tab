import Foundation
import UserNotifications
import UIKit







// MARK: - LocalTranscriptionError

enum LocalTranscriptionError: Error {
  case notEnoughMemory(available: UInt64, required: UInt64)
}

// MARK: - LocalTranscriptionWorkExecutor

final class LocalTranscriptionWorkExecutor: TranscriptionWorkExecutor {
  
  private var OPENAI_API_KEY = ""
  
  
  func showLocalNotification(with message: String) {
      let center = UNUserNotificationCenter.current()

      // Create the notification content
      let content = UNMutableNotificationContent()
      content.title = "GPT-3 Response"
      content.body = message
      content.sound = UNNotificationSound.default

      // Trigger the notification immediately
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

      // Create the request
      let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

      // Schedule the notification
      center.add(request) { (error) in
          if let error = error {
              print("Error showing notification: \(error.localizedDescription)")
          }
      }
  }
  
  
  
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
      request.addValue("Bearer \(OPENAI_API_KEY)", forHTTPHeaderField: "Authorization")
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")

      // Define your prompt
    let prompt: [String: Any] = [
        "model": "gpt-3.5-turbo",
        "messages": [
            ["role": "system", "content": "You are an assistant. You are tasked with extracting tasks from conversation. You are being fed transcriptions from other conversations. The text giving to you is transcriptions from conversations between other people. You need to extract helpful questions, advice, help based on large transcriptions you are fed. You are listening to transcriptions of conversations your user has had with other people, and you are tasked with giving them help. If there is nothing actionable the user needs help with, do not provide anything. Only ask questions that can be responded to, with a yes or no."],
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
  
  
  
  
  func checkTabNoFromGPT(transcript: String, completion: @escaping (Result<String, Error>) -> Void) {
      // Define API URL and request headers
    //let envKeys = loadEnvironmentKeys()
    //let apiKey = envKeys["OPENAI_API_KEY"]

    let openAIApiURL = URL(string: "https://api.openai.com/v1/chat/completions")!
      var request = URLRequest(url: openAIApiURL)
      request.httpMethod = "POST"
    request.addValue("Bearer \(OPENAI_API_KEY)", forHTTPHeaderField: "Authorization")
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")

      // Define your prompt
    let prompt: [String: Any] = [
        "model": "gpt-3.5-turbo",
        "messages": [
            ["role": "system", "content": "You are an assistant. You are being fed transcriptions that your user is having with others. You also have one really important task. If, at any time, the user says something along the lines of 'No Tab, I don't want help with that' or 'Tab, stop, I don't want any help with my outfit' or 'No Tab, I don't want help with picking this song.' then you need to extract what topic it is they're taking about. ONLY ABSOLUTELY SAY SOMETHING IF YOU ABSOLUTELY KNOW THEY TELL TAB SOMETHING TO STOP DOING. UNDER NO CIRCUMSTANCES SHOULD YOU SAY ANYTHING IF IT'S OTHERWISE. IF IT IS OTHERWISE, JUST SAY '-'."],
            ["role": "user", "content": "No Tab, I don't want help with the Tab logo"],
            ["role": "assistant", "content": "The user does not want help with the Tab logo"],
            ["role": "user", "content": "Tab, stop, I don't want any help with finding resources for quantum computing."],
            ["role": "assistant", "content": "The user does not want help with finding resources for quantum computing"],
            ["role": "user", "content": "Tab, I don't want help with picking my outfit"],
            ["role": "assistant", "content": "The user does not want help picking their outfit."],
            ["role": "user", "content": "That's so interesting, how did you learn about that? What's it called? wikipedia.com? Oh okay wow, I really need to check out that site thank you."],
            ["role": "assistant", "content": "-"],
            ["role": "user", "content": "I really need to go grocery shopping tomorrow, I'm not sure how I'll get there. How has your day been? Man that's really cool, I miss Florida hey. Yeah I should come soon."],
            ["role": "assistant", "content": "-"],
            ["role": "user", "content": "Yeah I'd love to learn more about quantum computing, I just always forget. Do you have any book recommendations? Oh that's awesome, yeah I'll check that out."],
            ["role": "assistant", "content": "-"],
            ["role": "user", "content": "Wow that's a lovely painting, where did you get it? Seems gorgeous, it must've cost a fortune aye? Wow yeah that's crazy"],
            ["role": "assistant", "content": "-"],
            ["role": "user", "content": "That's so interesting, how did you learn about that? What's it called? wikipedia.com? Oh okay wow, I really need to check out that site thank you."],
            ["role": "assistant", "content": "-"],
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
          
          checkTabNoFromGPT(transcript: transcription.text) { result in
              switch result {
              case .success(let content):
                  print("Received response: \(content)")

              case .failure(let error):
                  print("Error occurred: \(error.localizedDescription)")
                  // Handle the error, show error message to user, etc.
              }
          }
          
          sendTranscriptToGPT(transcript: transcription.text) { result in
              switch result {
              case .success(let content):
                  print("Received response: \(content)")
                DispatchQueue.main.async {
                  self.showLocalNotification(with: content)
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
