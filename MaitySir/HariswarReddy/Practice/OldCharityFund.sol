// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import OpenZeppelin contracts
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CharityDonationNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    // Token ID counter for NFTs
    Counters.Counter private _tokenIds;

    // Campaign struct to represent a purpose-based campaign
    struct Campaign {
        uint256 id;
        string name; 
        string description;
        // description
        bool isActive;
    }

    // Donation struct to store donor's donation data
    struct Donation {
        address donor;
        uint256 amount;
        string name; 
        // name
        uint256 timestamp;
        uint256[] vendorIds; 
        // remove vendor ids in donor and gets from foundation
    }

    // Vendor struct with purpose-based authorization
    struct Vendor {
        string name;
        mapping(string => bool) allowedPurposes;
        bool isRegistered;
    }

    // Invoice struct submitted by vendors
    struct Invoice {
        uint256 donationId;

        // removing donation id and adding compaign id
        string invoiceHash; // Could be an IPFS CID or external link have a file and take id as invoice
    }

uint256 [] public  campaignIds;
    // Mappings
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Donation) public donations;
    mapping(address => Vendor) public vendors;
    mapping(uint256 => Invoice[]) public donationInvoices;
    mapping(uint256 => address[]) public donationVendors;

    // ID Counters
    Counters.Counter private _campaignIds;
    Counters.Counter private _donationIds;

    // Events for transparency and tracking
    event CampaignCreated(uint256 indexed campaignId, string name,string description);
    event DonationMade(uint256 indexed donationId, address indexed donor, string purpose, uint256 amount);
    event VendorRegistered(address indexed vendor, string name);
    event VendorAssigned(uint256 indexed donationId, address indexed vendor);
    event InvoiceSubmitted(uint256 indexed donationId, address indexed vendor, string invoiceHash);
    event FundsReleased(address indexed vendor, uint256 amount);
    event OwnershipTransferredWithReason(address indexed oldOwner, address indexed newOwner, string reason);


    constructor() ERC721("CharityDonationNFT", "CDNFT") Ownable(msg.sender) {}

    // Allows the foundation to create a new campaign
    function createCampaign(string memory _name,string memory _description) external onlyOwner {
        uint256 newCampaignId = _campaignIds.current();
        campaigns[newCampaignId] = Campaign(newCampaignId,_name,_description, true);
        campaignIds.push(newCampaignId);
        _campaignIds.increment();
        emit CampaignCreated(newCampaignId, _name,_description);
    }


    function getAllCampaigns() public view returns (Campaign[] memory) {
     uint256 len = campaignIds.length;
     Campaign[] memory result = new Campaign[](len);

    for (uint i = 0; i < len; i++) {
        result[i] = campaigns[campaignIds[i]];
    }

    return result;
}

    // Foundation registers a vendor with allowed campaign purposes
    function registerVendor(address _vendor, string memory _name, string[] memory _purposes) external onlyOwner {
        Vendor storage vendor = vendors[_vendor];
        vendor.name = _name;
        vendor.isRegistered = true;

        for (uint i = 0; i < _purposes.length; i++) {
            vendor.allowedPurposes[_purposes[i]] = true;
        }

        emit VendorRegistered(_vendor, _name);
        // check emit and event
    }

    // Donor sends ETH along with the donation purpose
    function donate(string memory _name) external payable {
        require(msg.value > 0, "Donation must be > 0");

        uint256 newDonationId = _donationIds.current();
        Donation storage donation = donations[newDonationId];
        donation.donor = msg.sender;
        donation.amount = msg.value;
        donation.name = _name; 
        // changing name
        donation.timestamp = block.timestamp;

        // Mint NFT as proof of donation (soulbound)
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, "ipfs://metadata_link"); // Replace with actual metadata URI
        _tokenIds.increment();
        _donationIds.increment();

        emit DonationMade(newDonationId, msg.sender, _name, msg.value);
    }
  

    // Foundation assigns approved vendors to a donation
    function assignVendorsToDonation(uint256 _donationId, address[] memory _vendors) external onlyOwner {
        Donation storage donation = donations[_donationId];
        string memory purpose = donation.name;

        for (uint i = 0; i < _vendors.length; i++) {
            require(vendors[_vendors[i]].isRegistered, "Vendor not registered");
            require(vendors[_vendors[i]].allowedPurposes[purpose], "Vendor not approved for this purpose");

            donationVendors[_donationId].push(_vendors[i]);

            emit VendorAssigned(_donationId, _vendors[i]);
        }

        donation.vendorIds = new uint256[](_vendors.length); // optional indexing
    }
//    vendor should also give suggestions


    // Vendor uploads invoice hash for a donation.   using mongodb
    function submitInvoice(uint256 _donationId, string memory _invoiceHash) external {
        require(vendors[msg.sender].isRegistered, "Only registered vendors");

        // Ensure vendor was assigned to this donation
        bool isAssigned = false;
        for (uint i = 0; i < donationVendors[_donationId].length; i++) {
            if (donationVendors[_donationId][i] == msg.sender) {
                isAssigned = true;
                break;
            }
        }
        require(isAssigned, "Vendor not assigned to donation");

        donationInvoices[_donationId].push(Invoice(_donationId, _invoiceHash));

        emit InvoiceSubmitted(_donationId, msg.sender, _invoiceHash);
    }

    // Foundation sends ETH to vendors
    function releaseFunds(uint256 _donationId, address payable _vendor, uint256 _amount) external onlyOwner {
        require(vendors[_vendor].isRegistered, "Vendor not registered");
    require(address(this).balance >= _amount, "Insufficient contract balance");
    // adding conditions like invoice accepted invoice declined

    // Check that vendor is assigned to the given donation
    bool isAssigned = false;
    address[] storage assignedVendors = donationVendors[_donationId];
    for (uint i = 0; i < assignedVendors.length; i++) {
        if (assignedVendors[i] == _vendor) {
            isAssigned = true;
            break;
        }
    }
    require(isAssigned, "Vendor not assigned to this donation");

    // Transfer funds to vendor
    _vendor.transfer(_amount);

    emit FundsReleased(_vendor, _amount);
    }

    // Donor or public can view vendors assigned to a donation
    function getVendorsForDonation(uint256 _donationId) external view returns (address[] memory) {
        return donationVendors[_donationId];
    }

    // Donor or public can view invoices submitted for a donation
    function getInvoicesForDonation(uint256 _donationId) external view returns (Invoice[] memory) {
        return donationInvoices[_donationId];
    }
    // 🔄 Optional: emit custom event during ownership transfer
    function transferOwnershipWithReason(address newOwner, string memory reason) external onlyOwner {
        emit OwnershipTransferredWithReason(owner(), newOwner, reason);
        transferOwnership(newOwner);
    }
}
