// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ModernERC1155 is ERC1155, Ownable {
    using Strings for uint256;
    
    string public name;
    string public symbol;
    
    mapping(uint256 => string) private _tokenURIs;
    
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC1155(_uri) {
        name = _name;
        symbol = _symbol;
    }
    
    function mint(address to, uint256 id, uint256 amount, bytes memory data) 
        public onlyOwner 
    {
        _mint(to, id, amount, data);
    }
    
    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }
    
    function setURI(uint256 id, string memory newTokenURI) public onlyOwner {
        _tokenURIs[id] = newTokenURI;
        emit URI(newTokenURI, id);
    }
    
    function uri(uint256 id) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[id];
        
        // If token has specific URI, return it
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }
        
        // Otherwise return the baseURI from parent contract
        string memory baseURI = super.uri(id);
        
        // If the baseURI doesn't end with a slash and isn't empty, append a slash
        if (bytes(baseURI).length > 0 && bytes(baseURI)[bytes(baseURI).length - 1] != bytes1('/')) {
            return string(abi.encodePacked(baseURI, "/", Strings.toString(id)));
        }
        
        return string(abi.encodePacked(baseURI, Strings.toString(id)));
    }
}
