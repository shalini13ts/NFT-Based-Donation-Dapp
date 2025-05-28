// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CampaignNFT is ERC721, Ownable {
    enum Standard {
        PRIMARY_1, PRIMARY_2, PRIMARY_3, PRIMARY_4, PRIMARY_5,
        MIDDLE_6, MIDDLE_7, MIDDLE_8,
        HIGH_9, HIGH_10,
        INTER_11, INTER_12,
        BTECH_1, BTECH_2, BTECH_3, BTECH_4
    }

    struct Campaign {
        uint id;
        string name;
        string[] allowedSchoolTypes;   // dynamic list of allowed school types, e.g. ["govt", "private"]    based on clg name
        Standard[] allowedStandards;   // allowed standards in this campaign
        bool exists;
    }

    struct Student {
        address studentAddress;
        string schoolType;
        Standard standard;
        bytes32 admissionLetterHash;  
        bool approved;
        uint nftId; 
        uint campaignId;
    }

    struct Vendor {
        address vendorAddress;
        bool approved;
    }

    struct Donor {
        address donorAddress;
        uint totalDonated;
        bool exists;
    }
// each student gets to be in only one campaign
    uint public campaignCount;
    uint public studentCount;
    uint public vendorCount;
    uint public nftTokenId;

    mapping(uint => Campaign) public campaigns;
    mapping(uint => Student) public students;
    mapping(address => uint[]) public studentIdsByAddress;   
    // each student gets to be only in one campaign
    mapping(address => bool) public isStudentRegistered;

    mapping(address => Vendor) public vendors;

    mapping(Standard => uint) public standardAmount;

    mapping(uint => string) private _tokenURIs;


    mapping(uint => uint[]) public studentIdsByCampaign;
    mapping(uint => address[]) public donorsByCampaign;
    mapping(uint => mapping(address => uint)) public donorAmountByCampaign;
    mapping(uint => uint) public campaignBalances;

    mapping(uint => bool) public isNFTUsed;



    event CampaignCreated(uint campaignId, string name);
    event CampaignDonationReceived(uint campaignId, address donor, uint amount);
    event StudentRegistered(uint studentId, address studentAddress, uint campaignId);
    event StudentApproved(uint studentId, uint nftId);
    event VendorRegistered(address vendorAddress);
    event NFTUsed(uint nftId, address vendorAddress);

    constructor() ERC721("CampaignStudentNFT", "CSN") Ownable(msg.sender){
        // Initialize funding amounts for standards
        standardAmount[Standard.PRIMARY_1] = 1000;
        standardAmount[Standard.PRIMARY_2] = 1000;
        standardAmount[Standard.PRIMARY_3] = 1500;
        standardAmount[Standard.PRIMARY_4] = 1500;
        standardAmount[Standard.PRIMARY_5] = 2000;

        standardAmount[Standard.MIDDLE_6] = 2500;
        standardAmount[Standard.MIDDLE_7] = 2500;
        standardAmount[Standard.MIDDLE_8] = 3000;

        standardAmount[Standard.HIGH_9] = 3500;
        standardAmount[Standard.HIGH_10] = 4000;

        standardAmount[Standard.INTER_11] = 4500;
        standardAmount[Standard.INTER_12] = 5000;

        standardAmount[Standard.BTECH_1] = 8000;
        standardAmount[Standard.BTECH_2] = 8500;
        standardAmount[Standard.BTECH_3] = 9000;
        standardAmount[Standard.BTECH_4] = 10000;
    }

    // Foundation functions

    function createCampaign(
        string memory name,
        string[] memory allowedSchoolTypes,
        Standard[] memory allowedStandards
    ) external onlyOwner {
        campaignCount++;
        Campaign storage c = campaigns[campaignCount];
        c.id = campaignCount;
        c.name = name;
        c.exists = true;

        // Copy allowedSchoolTypes array
        for (uint i = 0; i < allowedSchoolTypes.length; i++) {
            c.allowedSchoolTypes.push(allowedSchoolTypes[i]);
        }
        // Copy allowedStandards array
        for (uint i = 0; i < allowedStandards.length; i++) {
            c.allowedStandards.push(allowedStandards[i]);
        }

        emit CampaignCreated(campaignCount, name);
    }

    function getAllCampaigns() external view returns (Campaign[] memory) {
        Campaign[] memory result = new Campaign[](campaignCount);
        for (uint i = 1; i <= campaignCount; i++) {
            result[i - 1] = campaigns[i];
        }
        return result;
    }


    function donateToCampaign(uint campaignId) external payable {
        require(campaigns[campaignId].exists, "Campaign does not exist");
        require(msg.value > 0, "Donation must be greater than 0");

        campaignBalances[campaignId] += msg.value;

        if (donorAmountByCampaign[campaignId][msg.sender] == 0) {
            donorsByCampaign[campaignId].push(msg.sender);
        }

        donorAmountByCampaign[campaignId][msg.sender] += msg.value;

        emit CampaignDonationReceived(campaignId, msg.sender, msg.value);
    }
// history of donor 


    function registerVendor(address vendorAddress) external onlyOwner {
        require(!vendors[vendorAddress].approved, "Vendor already registered");
        vendors[vendorAddress] = Vendor(vendorAddress, true);
        vendorCount++;
        emit VendorRegistered(vendorAddress);
    }

    function getDonorsByCampaign(uint campaignId) external view returns (Donor[] memory) {
        address[] memory donorAddresses = donorsByCampaign[campaignId];
        Donor[] memory result = new Donor[](donorAddresses.length);

        for (uint i = 0; i < donorAddresses.length; i++) {
            address donor = donorAddresses[i];
            result[i] = Donor(donor, donorAmountByCampaign[campaignId][donor], true);
        }

        return result;
    }

    // Student functions

    function registerForCampaign(
        uint campaignId,
        string memory studentSchoolType,
        Standard studentStandard,
        bytes32 admissionLetterHash  // mongo db file sharing
    ) external {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.exists, "Campaign does not exist");
        require(!isStudentRegistered[msg.sender], "Student already registered");

        // Check if student's school type is allowed by campaign
        bool schoolTypeAllowed = false;
        for (uint i = 0; i < campaign.allowedSchoolTypes.length; i++) {
            if (
                keccak256(bytes(campaign.allowedSchoolTypes[i])) ==
                keccak256(bytes(studentSchoolType))
            ) {
                schoolTypeAllowed = true;
                break;
            }
        }
        require(schoolTypeAllowed, "Student's school type not allowed");

        // Check if student's standard is allowed by campaign
        bool standardAllowed = false;
        for (uint i = 0; i < campaign.allowedStandards.length; i++) {
            if (campaign.allowedStandards[i] == studentStandard) {
                standardAllowed = true;
                break;
            }
        }
        require(standardAllowed, "Student's standard not allowed");

        studentCount++;
        students[studentCount] = Student(
            msg.sender,
            studentSchoolType,
            studentStandard,
            admissionLetterHash,
            false,
            0,
            campaignId
        );

        studentIdsByAddress[msg.sender].push(studentCount);
        isStudentRegistered[msg.sender] = true;
        studentIdsByCampaign[campaignId].push(studentCount);
        emit StudentRegistered(studentCount, msg.sender, campaignId);
    }

    function getStudentsByCampaign(uint campaignId) external view returns (Student[] memory) {
        uint[] memory ids = studentIdsByCampaign[campaignId];
        Student[] memory result = new Student[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            result[i] = students[ids[i]];
        }
        return result;
    }

    // Foundation approves student, mints NFT to the student

    function approveStudent(uint studentId, string memory tokenURII) external onlyOwner {
        Student storage student = students[studentId];
        require(!student.approved, "Student already approved");
        require(student.studentAddress != address(0), "Invalid student");
// should check the student data and approve like admission letter 
        student.approved = true;
// using amount the nft should be minted
        nftTokenId++;
        _safeMint(student.studentAddress, nftTokenId);
        _setTokenURI(nftTokenId, tokenURII);

        student.nftId = nftTokenId;

        emit StudentApproved(studentId, nftTokenId);
    }
    function getStudentAddressesByCampaign(uint campaignId) external view onlyOwner returns (address[] memory) {
        uint[] memory ids = studentIdsByCampaign[campaignId];
        address[] memory studentAddresses = new address[](ids.length);

        for (uint i = 0; i < ids.length; i++) {
            studentAddresses[i] = students[ids[i]].studentAddress;
        }

        return studentAddresses;
    }
    // can be removed getStudentAddressesByCampaign
    function getApprovedStudentsByCampaign(uint campaignId) external view onlyOwner returns (Student[] memory) {
        uint[] memory ids = studentIdsByCampaign[campaignId];

        // First, count how many students are approved
        uint approvedCount = 0;
        for (uint i = 0; i < ids.length; i++) {
            if (students[ids[i]].approved) {
                approvedCount++;
            }
        }

        // Creating an array of approved students
        Student[] memory approvedStudents = new Student[](approvedCount);
        uint index = 0;
        for (uint i = 0; i < ids.length; i++) {
            if (students[ids[i]].approved) {
                approvedStudents[index] = students[ids[i]];
                index++;
            }
        }

        return approvedStudents;
    }


    // Internal token URI

    function _setTokenURI(uint tokenId, string memory _tokenURI) internal virtual {
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint tokenId) public view virtual override returns (string memory) {
        // require(_ownerOf(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    // Vendor verifies and uses NFT

    function verifyAndUseNFT(uint nftId) external {
        require(vendors[msg.sender].approved, "Not an approved vendor");
        require(!isNFTUsed[nftId], "NFT already used");
        isNFTUsed[nftId] = true;

        // require(_ownerOf(nftId), "NFT does not exist");
        address owner = ownerOf(nftId);
        require(owner != address(0), "NFT has no owner");
        // transfering to vendor should be there so that no need of checking if the nft is used
        emit NFTUsed(nftId, msg.sender);
    }

    // Get funding amount for standard

    function getAmountByStandard(Standard standard) external view returns (uint) {
        return standardAmount[standard];
    }

    // Get student's NFTs

    function getStudentNFTs(address studentAddress) external view returns (uint[] memory) {
        uint[] memory ids = studentIdsByAddress[studentAddress];
        uint count = 0;

        for (uint i = 0; i < ids.length; i++) {
            if (students[ids[i]].approved) {
                count++;
            }
        }

        uint[] memory nftIds = new uint[](count);
        uint index = 0;
        for (uint i = 0; i < ids.length; i++) {
            if (students[ids[i]].approved) {
                nftIds[index] = students[ids[i]].nftId;
                index++;
            }
        }
        return nftIds;
    }
    // change to onlyOwner

    // getting campaign balance
    function getCampaignBalance(uint campaignId) external view onlyOwner returns (uint) {
        return campaignBalances[campaignId];
    }

    // getting each donors amount for campaign
    function getDonorsWithAmountsByCampaign(uint campaignId) external view onlyOwner returns (address[] memory, uint[] memory) {
        address[] memory donors = donorsByCampaign[campaignId];
        uint[] memory amounts = new uint[](donors.length);

        for (uint i = 0; i < donors.length; i++) {
            amounts[i] = donorAmountByCampaign[campaignId][donors[i]];
        }

        return (donors, amounts);
    }

}
