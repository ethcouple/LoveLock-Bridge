// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title LoveLockNFT
 * @dev ERC721 token representing a love lock on the bridge
 */
contract LoveLockNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIdCounter;
    
    // LoveLockERC20 contract address
    address public loveLockTokenAddress;
    
    // Metadata structure
    struct LockMetadata {
        string lover1Name;
        string lover2Name;
        uint256 lockDate;
        string message;
        bool keyThrown;  // Whether the key has been thrown away
    }
    
    // Mapping from token ID to metadata
    mapping(uint256 => LockMetadata) public lockMetadata;
    
    // Statistics
    uint256 public totalLocksCreated;
    uint256 public totalKeysThrown;
    
    // Events
    event LockCreated(uint256 indexed tokenId, address indexed creator, string lover1, string lover2);
    event KeyThrown(uint256 indexed tokenId, address indexed owner);
    
    constructor() ERC721("LoveLock", "LOCK") {}
    
    /**
     * @dev Set the LoveLockToken contract address
     */
    function setLoveLockTokenAddress(address _tokenAddress) external onlyOwner {
        loveLockTokenAddress = _tokenAddress;
    }
    
    /**
     * @dev Mint a new love lock NFT
     */
    function createLoveLock(
        string memory lover1Name,
        string memory lover2Name,
        string memory message,
        string memory tokenURI
    ) public returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        lockMetadata[tokenId] = LockMetadata({
            lover1Name: lover1Name,
            lover2Name: lover2Name,
            lockDate: block.timestamp,
            message: message,
            keyThrown: false
        });
        
        totalLocksCreated++;
        
        // Mint corresponding LoveLockToken
        if (loveLockTokenAddress != address(0)) {
            ILoveLockToken(loveLockTokenAddress).mintTokens(msg.sender, tokenId);
        }
        
        emit LockCreated(tokenId, msg.sender, lover1Name, lover2Name);
        
        return tokenId;
    }
    
    /**
     * @dev Throw away the key (seal eternal love)
     */
    function throwKey(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "You don't own this lock");
        require(!lockMetadata[tokenId].keyThrown, "Key already thrown");
        
        lockMetadata[tokenId].keyThrown = true;
        totalKeysThrown++;
        
        // Burn the ERC20 tokens
        if (loveLockTokenAddress != address(0)) {
            ILoveLockToken(loveLockTokenAddress).burnTokens(msg.sender, tokenId);
        }
        
        emit KeyThrown(tokenId, msg.sender);
    }
    
    /**
     * @dev Get statistics
     */
    function getStatistics() external view returns (uint256 locksCreated, uint256 keysThrown) {
        return (totalLocksCreated, totalKeysThrown);
    }
}

/**
 * @title LoveLockToken
 * @dev ERC20 token representing the key to a love lock
 */
contract LoveLockToken is ERC20, Ownable {
    address public loveLockNFTAddress;
    uint256 public constant TOKENS_PER_LOCK = 1 * 10**18; // 1 TOKEN per lock
    
    // Track minted tokens for each NFT
    mapping(uint256 => bool) public tokenMinted;
    mapping(uint256 => bool) public tokenBurned;
    
    // Burn address
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    // Events
    event TokensMinted(address indexed to, uint256 indexed lockId, uint256 amount);
    event TokensBurned(address indexed from, uint256 indexed lockId, uint256 amount);
    
    constructor() ERC20("LoveLock Token", "KEY") {}
    
    /**
     * @dev Set the NFT contract address
     */
    function setLoveLockNFTAddress(address _nftAddress) external onlyOwner {
        loveLockNFTAddress = _nftAddress;
    }
    
    /**
     * @dev Mint tokens corresponding to an NFT
     */
    function mintTokens(address to, uint256 lockId) external {
        require(msg.sender == loveLockNFTAddress, "Only NFT contract can mint");
        require(!tokenMinted[lockId], "Tokens already minted for this lock");
        
        tokenMinted[lockId] = true;
        _mint(to, TOKENS_PER_LOCK);
        
        emit TokensMinted(to, lockId, TOKENS_PER_LOCK);
    }
    
    /**
     * @dev Burn tokens (throw away the key)
     */
    function burnTokens(address from, uint256 lockId) external {
        require(msg.sender == loveLockNFTAddress, "Only NFT contract can burn");
        require(tokenMinted[lockId], "No tokens minted for this lock");
        require(!tokenBurned[lockId], "Tokens already burned for this lock");
        
        tokenBurned[lockId] = true;
        
        // Transfer tokens to burn address
        _transfer(from, BURN_ADDRESS, TOKENS_PER_LOCK);
        
        emit TokensBurned(from, lockId, TOKENS_PER_LOCK);
    }
    
    /**
     * @dev Get total burned tokens
     */
    function getTotalBurned() external view returns (uint256) {
        return balanceOf(BURN_ADDRESS);
    }
}

// Interface
interface ILoveLockToken {
    function mintTokens(address to, uint256 lockId) external;
    function burnTokens(address from, uint256 lockId) external;
}
