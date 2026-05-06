class AppStrings {
  // Common / General
  static const String appTitle = 'Home Organizer';
  static const String cancel = 'Cancel';
  static const String create = 'Create';
  static const String save = 'Save';
  static const String update = 'Update';
  static const String close = 'Close';
  static const String delete = 'Delete';
  static const String searchHint = 'Search for an item';
  
  // Home Screen
  static const String welcomeTo = 'Welcome to';
  static const String homeFooter = '"A place for everything, and everything in its place."';
  static const String findThings = 'Find My Things';
  static const String findThingsSubtitle = 'Locate items in your home';
  static const String reminders = 'Reminders';
  static const String remindersSubtitle = 'Set and manage reminders';
  static const String medicalWardrobe = 'Medical Wardrobe';
  static const String medicalWardrobeSubtitle = 'Track medicines & expiry';
  static const String inventory = 'Inventory';
  static const String inventorySubtitle = 'Manage household items';

  // Find Things Screen
  static const String selectHouseType = 'Select House Type';
  static const String type1BHK = '1 BHK';
  static const String type2BHK = '2 BHK';
  static const String type3BHK = '3 BHK';
  static const String layout1BHK = '1 BHK Layout';
  static const String layout2BHK = '2 BHK Layout';
  static const String layout3BHK = '3 BHK Layout';
  static const String createCustomHouse = 'Create Custom House';
  static const String customHouseDetails = 'Custom House Details';
  static const String houseNameLabel = 'House Name (optional)';
  static const String houseNameHint = 'e.g. Lake View';
  static const String bedrooms = 'Bedrooms';
  static const String bathrooms = 'Bathrooms';
  static const String halls = 'Halls';
  static const String kitchens = 'Kitchens';
  static const String layoutCode = 'Layout code';

  // House Layout Screen
  static const String layoutHelp = 'Long press and drag blocks to rearrange the layout. Tap to enter.';
  static const String searchInHouse = 'Search items in this house...';
  static const String typeToSearch = 'Type to search...';
  static const String noItemsFound = 'No items found';

  // Room Items Screen
  static const String noItemsInRoom = 'No items in';
  static const String tapToAddItem = 'Tap + to add an item';
  static const String itemDetailsInfo = 'Item details';
  static const String categoryLabel = 'Category';
  static const String locationLabel = 'Location';
  static const String purchaseDateLabel = 'Purchase date';
  static const String expiryDateLabel = 'Expiry date';
  static const String notSet = 'Not set';

  // Add Item Screen
  static const String addItem = 'Add Item';
  static const String editItem = 'Edit Item';
  static const String itemNameLabel = 'Item Name';
  static const String itemNameHint = 'e.g., Passport';
  static const String specificLocationLabel = 'Specific Location';
  static const String specificLocationHint = 'e.g., Top Drawer';
  static const String addPhoto = 'Add photo';
  static const String takePhoto = 'Take photo';
  static const String chooseFromGallery = 'Choose from gallery';
  static const String selectPurchaseDate = 'Select Purchase Date';
  static const String selectExpiryDate = 'Select Expiry Date';
  static const String saveItem = 'Save Item';
  static const String updateItem = 'Update Item';
  static const String errorEnterName = 'Please enter a name';
  static const String errorEnterLocation = 'Please enter a location';
  
  // Helpers
  static String roomItemsTitle(String roomName) => '$roomName Items';
  static String noItemsYet(String roomName) => 'No items in $roomName yet';

  // Inventory Screen
  static const String inventoryBedrooms = 'Bedrooms';
  static const String inventoryKitchens = 'Kitchens';
  static const String inventoryBathrooms = 'Bathrooms';
  static const String inventoryHalls = 'Halls';
  static const String inventoryGroceries = 'Groceries';
  static const String inventoryAllItems = 'All Items';
  static const String searchInventoryHint = 'Search items by name...';
  static String noItemsIn(String title) => 'No items found in $title';
  static String itemCountText(int count) => '$count Items';
  static String roomPrefix(String roomName) => 'Room: $roomName';
  static String locationPrefix(String location) => 'Location: $location';
  static String categoryPrefix(String category) => 'Category: $category';
}
