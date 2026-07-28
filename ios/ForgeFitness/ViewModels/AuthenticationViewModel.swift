import Combine

final class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
}
