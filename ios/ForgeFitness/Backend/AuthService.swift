import Supabase

final class AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }
}
