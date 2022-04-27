// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "./lib/Signing.sol";
import "hardhat/console.sol";

contract GigaSpaceLandBase is Initializable, ERC721Upgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC721BurnableUpgradeable, ERC721URIStorageUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    mapping (uint256 => uint256) public _price;

    enum SalePhase {
		Locked,
		PrivateSale,
		PublicSale
	}

    SalePhase public _phase;

    uint256 internal constant MAP_SIZE = 504;

    uint256 internal constant LAYER_1x1 =      100000000000000;
    uint256 internal constant LAYER_3x3 =      300000000000000;
    uint256 internal constant LAYER_6x6 =      600000000000000;
    uint256 internal constant LAYER_12x12 =    120000000000000;
    uint256 internal constant LAYER_24x24 =    240000000000000;

    mapping (uint256 => uint256) public _landOwners;
    mapping (uint256 => address) public _newLandOwners;
    mapping (address => uint256) public _numNFTPerAddress;

    address internal _adminSigner;

    mapping(address=>address) internal _signatures;

    string internal _baseTokenURI;

 
    function initialize(address adminSigner, string memory uri) public initializer {
        __ERC721_init("GigaSpace", "GIS");
        __ERC721URIStorage_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        _adminSigner = adminSigner;
        _baseTokenURI = uri;
        _phase = SalePhase.Locked;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Set IPFS base URI
    function setBaseTokenURI(string memory uri) external onlyRole(DEFAULT_ADMIN_ROLE)  {
        _baseTokenURI = uri;
    }

    /// @notice Set the land price of 5 layers
    function setPrice(uint256 layer, uint256 price) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _price[layer] = price;
    }

	/// @notice Set the sale phase state 
    function enterPhase(SalePhase phase) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _phase = phase;
    }

    /// @notice total width of the map
    /// @return width
    function width() external pure returns(uint256) {
        return MAP_SIZE;
    }

    /// @notice total height of the map
    /// @return height
    function height() external pure returns(uint256) {
        return MAP_SIZE;
    }

    function scaleXY(int256 scale) private pure returns (uint256) {
        return uint(scale + 1000);
    }

    function privateMint(address to, uint256 size, int256 x, int256 y, string memory uri, bytes memory signature) public payable callerIsUser {
        require(_phase == SalePhase.PrivateSale, "Private phase is not active");
        mintLand(to, size, scaleXY(x), scaleXY(y), uri, signature);
    }    

    function publicMint(address to, uint256 size, int256 x, int256 y, string memory uri, bytes memory signature) public payable callerIsUser {
        require(_phase == SalePhase.PublicSale, "Public phase is not active");
        mintLand(to, size,  scaleXY(x), scaleXY(y), uri, signature);
    }    
    
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "Contract as user is not allowed");
        _;
    }

    function mintLand(address to, uint256 size, uint256 x, uint256 y, string memory landUri, bytes memory signature) internal {

        require(to != address(0), "to is zero address");
        require(_processSignature(_adminSigner, msg.sender, size, x, y, signature), "Not an authorized address"); 
        require(msg.value >= _price[size], "Insufficient payment");

        uint256 quadId = _formQuadId(size, x, y);

        uint256 landId;
        uint256 xNew = x; 
        uint256 yNew = y; 

        //Assign all the landIds to _landOwners, if 1x1, no need
        if (size > 1) {
            for (uint256 i = 0; i < size*size; i++) {
                    landId = xNew + yNew * MAP_SIZE;

                    //Reserve [0] for quadId assiging to _landOwners
                    if (i != 0)
                        _landOwners[landId] = uint256(uint160(address(to)));
                    
                    if ((i+1) % size == 0) {
                        yNew += 1;
                        xNew = x;
                    } else 
                        xNew += 1; 
            }
        }    
        //For any size of land, mint 1 ERC721 token only by quadId
        _safeMint(to, quadId, landUri);
        _landOwners[quadId] = uint256(uint160(address(to)));
        _numNFTPerAddress[to] += size * size;
    }

    function _formQuadId(uint256 size, uint256 x, uint256 y) internal pure returns (uint256) {
        uint256 id = x + y * MAP_SIZE;
        uint256 quadId;

        if (size == 1) {
            quadId = LAYER_1x1 + id;
        } else if (size == 3) {
            quadId = LAYER_3x3 + id;
        } else if (size == 6) {
            quadId = LAYER_6x6 + id;
        } else if (size == 12) {
            quadId = LAYER_12x12 + id;
        } else if (size == 24) {
            quadId = LAYER_24x24 + id;
        } else {
            require(false, "Invalid size");
        }
        return quadId;

    }

    /// @notice Degroup the quad to 1x1
    /// @param erc721Id the ERC721 token ID on chain
    /// @param to Destination
    /// @param size Size of the quad
    /// @param x The bottom left x coordinate of the quad
    /// @param y The bottom left y coordinate of the quad
    /// @param landUri All degrouped token URIs
    function deGroupLand(uint256 erc721Id, address to, uint256 size, int256 x, int256 y, string[] memory landUri) external onlyRole(DEFAULT_ADMIN_ROLE) {

        uint256 quadId = _formQuadId(size, scaleXY(x), scaleXY(y));

        require(to != address(0), "to is zero address");
        require(size > 1, "Only quad can deGroup");
        require(quadId == erc721Id, "Invalid ERC721 token ID");
   
        uint256 landId;
        uint256 xNew = scaleXY(x); 
        uint256 yNew = scaleXY(y); 

        _burn(erc721Id);
        _landOwners[quadId] = 0;

        _numNFTPerAddress[to] -= 1;

       for (uint256 i = 0; i < size*size; i++) {

             landId = LAYER_1x1 + xNew + yNew * MAP_SIZE;
        
             _safeMint(to, landId, landUri[i]);

            _landOwners[landId] = uint256(uint160(address(to)));
            
            if ((i+1) % size == 0) {
                yNew += 1;
                xNew = scaleXY(x);
            } else 
                xNew += 1; 
        }
        _numNFTPerAddress[to] -= size * size;
    }        

    function _safeMint(address to, uint256 tokenId, string memory uri) internal {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    /// @notice transfer quad with lands to destination
    /// @param from current owner of the quad
    /// @param to destination
    /// @param size size of the quad
    /// @param x The bottom left x coordinate of the quad
    /// @param y The bottom left y coordinate of the quad
    function transferQuad(address from, address to, uint256 size, int256 x, int256 y) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(from != address(0), "from is zero address");
        require(to != address(0), "can't send to zero address");
        
        _transferQuad(from, to, size, scaleXY(x), scaleXY(y));
        _numNFTPerAddress[from] -= size * size;
        _numNFTPerAddress[to] += size * size;

    }

    function _transferQuad(address from, address to, uint256 size, uint256 x, uint256 y) internal {

        require(_quadOwnerOf(size, x, y) == from, "Quad land is not owner");

        uint256 quadId = _formQuadId(size, x, y);

        if (size > 1) {
            uint256 xNew = x; 
            uint256 yNew = y; 
            uint256 landId;
            
            for (uint256 i = 0; i < size*size; i++) {
                    landId = xNew + yNew * MAP_SIZE;                
                    
                    // Start from xNew+1, because 1st land is quadId
                    if (i > 0)
                        _landOwners[landId] = uint256(uint160(address(to)));
                    
                    if ((i+1) % size == 0) {
                        yNew += 1;
                        xNew = x;
                    } else 
                        xNew += 1; 
            }
        }
        _landOwners[quadId] = uint256(uint160(address(to)));
        safeTransferFrom(from, to, quadId);
    }    

    function scaleLandOwnerOf(int256 x, int256 y) public view returns (address) {
        return _landOwnerOf(scaleXY(x), scaleXY(y));
    }    

    function _landOwnerOf(uint256 x, uint256 y) internal view returns (address) {
        uint256 landId = x + y * MAP_SIZE;
        return address(uint160(uint256(_landOwners[landId])));
    }

    function scaleQuadOwnerOf(uint256 size, int256 x, int256 y) public view returns (address) {
        uint256 scaleX = scaleXY(x);
        uint256 scaleY = scaleXY(y);
        return _quadOwnerOf(size, scaleX, scaleY);
    }

    function _quadOwnerOf(uint256 size, uint256 x, uint256 y) internal view returns (address) {    
        uint256 quadId = _formQuadId(size, x, y);
        
        return _quadAdd(quadId);
    }

    function _quadAdd(uint256 quadId) public view returns (address) {
        return address(uint160(uint256(_landOwners[quadId])));
    }

    ///@notice checks the signature
    ///@param userFrom - user creator of the signature
    ///@param userTo - user receiver of the signature
    ///@param signature - bytes with the signed message
    function _processSignature(address userFrom, address userTo, uint256 size, uint256 x, uint256 y, bytes memory signature) internal pure returns (bool) {
        
        bytes32 message = Signing.formMessage(userFrom, userTo, size, x, y);
        require(userFrom == Signing.recoverAddress(message, signature), "Invalid signature provided");
        return true;
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

