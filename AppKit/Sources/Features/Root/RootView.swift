import Combine
import ComposableArchitecture
import Inject
import SwiftUI
import UserNotifications


func sendNotifToGPT(transcript: String, completion: @escaping (Result<String, Error>) -> Void) {
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
          ["role": "system", "content": "You are an assistant. When receiving a header, you provide back useful information."],
          ["role": "user", "content": "Is there anything specific you want to know about quantum computing?"],
          ["role": "assistant", "content": "Quantum computing is a rapidly evolving field that leverages the principles of quantum mechanics to process information. Unlike classical computers, which use bits as the basic unit of information, quantum computers use quantum bits or qubits. Here's a breakdown of some key aspects:1. Qubits:Basic Unit: In classical computing, a bit is the basic unit of information and can be either 0 or 1. In quantum computing, a qubit can be in a state of 0, 1, or any quantum superposition of these states.Superposition: This principle allows a qubit to be in multiple states simultaneously, vastly increasing the computational power.2. Entanglement:Connected Qubits: Quantum entanglement is a phenomenon where qubits become interconnected and the state of one qubit can instantaneously affect the state of another, no matter the distance between them.Parallel Processing: This property enables quantum computers to perform many calculations at once, providing potential for exponential speedups for certain problems.3. Quantum Gates:Manipulating Qubits: Quantum gates are used to manipulate qubits, similar to how logic gates are used in classical computing. They are the building blocks of quantum circuits.Complex Operations: Quantum gates allow for more complex operations than classical gates due to the properties of superposition and entanglement.4. Quantum Algorithms:Shor's Algorithm: For factoring large numbers much more efficiently than the best-known algorithms on classical computers. This has significant implications for cryptography.Grover's Algorithm: For searching unsorted databases much faster than classical algorithms.5. Current Challenges:Error Rates: Quantum computers are prone to errors due to decoherence and noise. Quantum error correction is a significant area of research.Scalability: Building and maintaining a large number of qubits is technically challenging.Temperature: Quantum computers often require extremely low temperatures to function, making them complex and expensive to maintain.6. Potential Applications:Cryptography: Though posing a threat to current cryptographic systems, quantum computing also offers pathways to more secure encryption methods.Drug Discovery: Simulating molecular structures could revolutionize drug development.Optimization Problems: Solutions for complex optimization problems in logistics, finance, and other fields.Artificial Intelligence: Could enhance machine learning algorithms and processing capabilities.7. State of the Field:As of 2023, quantum computing is still largely in the experimental and developmental stage. Companies like Google, IBM, and startups are making significant strides in building quantum computers and developing algorithms.Quantum supremacy, where a quantum computer performs a calculation that is practically impossible for classical computers, has been claimed but remains a topic of debate and ongoing research.8. Looking Ahead:Quantum Internet: Concepts for a quantum internet are being explored, which would use quantum entanglement for secure communication.Quantum vs. Classical: Quantum computers won’t replace classical computers but will rather complement them, being used for specific tasks where they have a clear advantage.Quantum computing is poised to revolutionize various fields, but it's still a technology in its infancy, facing significant technical hurdles. However, its potential makes it one of the most exciting areas of research in computer science and physics."],
          ["role": "user", "content": "Would you like to learn more about nuclear fusion?"],
          ["role": "assistant", "content": "Nuclear fusion is the process where two light atomic nuclei combine to form a heavier nucleus, releasing a significant amount of energy. This process is what powers stars, including our Sun. In the core of a star, the high temperature and pressure allow for fusion reactions to take place, primarily converting hydrogen into helium.Key Concepts:Energy Release: Fusion releases energy because the mass of the resulting nucleus is slightly less than the sum of its parts. This lost mass is converted into energy according to Einstein's equation, E=mc².Fusion in Stars: In stars, hydrogen nuclei (protons) fuse to form helium through a series of steps known as the proton-proton chain or the CNO cycle, depending on the star's size.Conditions for Fusion: Fusion requires extremely high temperatures and pressures to overcome the electrostatic repulsion between positively charged nuclei. This is why fusion occurs in the core of stars.Fuel: The most commonly discussed fusion reactions for energy production on Earth are Deuterium-Tritium (D-T) and Deuterium-Deuterium (D-D). Deuterium is a stable isotope of hydrogen, and tritium is a radioactive isotope.Challenges for Fusion Energy on Earth:Containment: Containing the hot plasma (over 100 million degrees Celsius) is a major challenge. The plasma cannot touch any material container, so magnetic confinement (like in tokamaks) or inertial confinement (using lasers) are methods being explored.Sustainability: Achieving a sustained fusion reaction that produces more energy than it consumes is a significant challenge. As of my last update in April 2023, this had not been achieved for a prolonged period.Materials and Safety: Handling the extreme conditions and the neutron bombardment that occurs during fusion reactions requires advanced materials. Fusion is safer than fission in terms of radioactive waste and meltdown risks, but it still has its safety challenges.Economic Viability: The technology must be economically feasible. The cost of building and maintaining a fusion reactor and the cost per unit of energy produced are crucial factors.Potential Benefits of Fusion Energy:Abundant Fuel: Deuterium can be extracted from water, and tritium can be bred from lithium, making the fuel relatively abundant. Low Carbon Emissions: Fusion does not produce greenhouse gases during operation, making it a clean energy source.Reduced Radioactive Waste: Compared to fission, fusion produces less long-lived radioactive waste.Safety: There is no risk of a meltdown like in fission reactors, and a runaway fusion reaction is not possible due to the precise conditions required for fusion.Current Status:As of my last update in April 2023, nuclear fusion for practical energy production remained an area of active research. Facilities like ITER (International Thermonuclear Experimental Reactor) and various national and private ventures were working on overcoming the challenges. While significant progress has been made, the realization of fusion as a practical energy source is still considered to be years, if not decades, away."],
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



class ViewModel: ObservableObject {
    @Published var notificationResult: String = ""
    var cancellables: Set<AnyCancellable> = []

    func fetchNotifContent(from transcript: String) {
        sendNotifToGPT(transcript: transcript) { [weak self] result in
            switch result {
            case .success(let content):
                self?.notificationResult = content
            case .failure(let error):
                self?.notificationResult = "Error: \(error.localizedDescription)"
            }
        }
    }
}

struct NotificationDetailView: View {
    @ObservedObject var viewModel = ViewModel()
    let notificationText: String

    var body: some View {
        VStack {
            Text(viewModel.notificationResult)
                .padding()
            Button("Fetch Content") {
                viewModel.fetchNotifContent(from: notificationText)
            }
        }
        .onAppear(perform: {
            viewModel.fetchNotifContent(from: notificationText)
        })
    }
}

// MARK: - RootView
struct RootView: View {
  private let notificationDelegate = UNUserNotificationCenterDelegateAdaptor()
  @State private var showNotificationDetail: Bool = false


      func requestNotificationPermission() {
          let center = UNUserNotificationCenter.current()
          center.delegate = notificationDelegate  // Use the stored delegate
          center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
              if granted {
                  print("Notification permissions granted.")
              } else {
                  print("Notification permissions denied.")
              }
          }
      }
  
  @ObserveInjection var inject

  let store: StoreOf<Root>

  @ObservedObject var viewStore: ViewStore<Root.Tab, Root.Action>

  @Namespace var animation

  init(store: StoreOf<Root>) {
    self.store = store
    viewStore = ViewStore(store) { $0.selectedTab }
  }

  // State variables
  @State private var buttonText = "Test Notification Detail"

  var body: some View {
    
      NavigationView {
        VStack {
          Button(buttonText) {
              showNotificationDetail.toggle()
          }
          
          ZStack {
              TabBarContainerView(
                  selectedIndex: viewStore.binding(get: \.rawValue, send: Root.Action.selectTab),
                  screen1: RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: Root.Action.recordingListScreen)),
                  screen2: RecordScreenView(store: store.scope(state: \.recordScreen, action: Root.Action.recordScreen)),
                  screen3: SettingsScreenView(store: store.scope(state: \.settingsScreen, action: Root.Action.settingsScreen))
              )
              .accentColor(.white)
              .onAppear(perform: requestNotificationPermission)
              .task { viewStore.send(.task) }
              .enableInjection()
              
              .sheet(isPresented: $showNotificationDetail) {
                NotificationDetailView(notificationText: buttonText)
              }
          }
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowNotificationDetail"))) { notification in
          print("Received the notification in the view!")
          if let body = notification.userInfo?["body"] as? String {
              buttonText = body
          }
      }
      
  }




}

class UNUserNotificationCenterDelegateAdaptor: NSObject, UNUserNotificationCenterDelegate {
    
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      completionHandler([.banner, .sound, .badge])
  }

    
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
      
      // Accessing the notification content
      let content = response.notification.request.content
      
      // Extracting the title, subtitle, and body of the notification
      let title = content.title
      let subtitle = content.subtitle
      let body = content.body
      
      print("Title: \(title), Subtitle: \(subtitle), Body: \(body)")
    
      print("Tapped the notification!")
      
      // Post a custom notification to indicate that the notification was tapped
    NotificationCenter.default.post(name: Notification.Name("ShowNotificationDetail"), object: nil, userInfo: ["body": body])

      completionHandler()
  }

  
  

}


// MARK: - Root_Previews

struct Root_Previews: PreviewProvider {
  struct ContentView: View {
    var body: some View {
      RootView(
        store: Store(
          initialState: Root.State(),
          reducer: { Root() }
        )
      )
    }
  }

  static var previews: some View {
    ContentView()
  }
}
