import '../models/sell_request.dart';

class UserRepository {
  // Mock data layer for future backend integration
  static final List<SellRequest> _mockSellRequests = [];
  
  static List<SellRequest> getSellRequests() {
    return List.unmodifiable(_mockSellRequests);
  }
  
  static void addSellRequest(SellRequest request) {
    _mockSellRequests.add(request);
  }
}

