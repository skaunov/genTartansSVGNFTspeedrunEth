//SPDX-License-Identifier: MIT
// pragma solidity >=0.6.0 <0.7.0;
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import 'base64-sol/base64.sol';

import "hardhat/console.sol";

import './HexStrings.sol';
import './ToColor.sol';
//learn more: https://docs.openzeppelin.com/contracts/3.x/erc721

// GET LISTED ON OPENSEA: https://testnets.opensea.io/get-listed/step-two

contract YourCollectible is ERC721, Ownable {

  struct TartanStripe {
    bytes3 color;
    uint8 size;
  }
  /* a tartan is an array of 9 stripes?
  9 * 3 = 27 of 32 and 5 for sizes
  ___________________
  or
  5 * 3 = 15 of 32; so 7 bytes left */
  
  using Strings for uint256;
  using Strings for uint8;
  using HexStrings for uint160;
  using ToColor for bytes3;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  mapping (uint256 => bytes3) public color;
  mapping (uint256 => uint256) public chubbiness;
  mapping (uint256 => bytes32) seed;

  uint256 mintDeadline = block.timestamp + 24 hours;

  constructor() public ERC721("Loogies", "LOOG") {
    // RELEASE THE LOOGIES!
  }

  function mintItem()
      public
      returns (uint256)
  {
      require( block.timestamp < mintDeadline, "DONE MINTING");
      _tokenIds.increment();

      uint256 id = _tokenIds.current();
      _mint(msg.sender, id);

      seed[id] = keccak256(abi.encodePacked( blockhash(block.number-1), msg.sender, address(this) ));
      // color[id] = bytes2(predictableRandom[0]) | ( bytes2(predictableRandom[1]) >> 8 ) | ( bytes3(predictableRandom[2]) >> 16 );
      // chubbiness[id] = 35+((55*uint256(uint8(predictableRandom[3])))/255);

      return id;
  }

  function tokenURI(uint256 id) public view override returns (string memory) {
      require(_exists(id), "not exist");
      string memory name = string(abi.encodePacked('Loogie #',id.toString()));
      string memory description = string(abi.encodePacked('This Loogie is the color #',color[id].toColor(),' with a chubbiness of ',uint2str(chubbiness[id]),'!!!'));
      string memory image = Base64.encode(bytes(generateSVGofTokenById(id)));

      return
          string(
              abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                          abi.encodePacked(
                              '{"name":"',
                              name,
                              '", "description":"',
                              description,
                              '", "external_url":"https://burnyboys.com/token/',
                              id.toString(),
                              '", "attributes": [{"trait_type": "color", "value": "#',
                              color[id].toColor(),
                              '"},{"trait_type": "chubbiness", "value": ',
                              uint2str(chubbiness[id]),
                              '}], "owner":"',
                              (uint160(ownerOf(id))).toHexString(20),
                              '", "image": "',
                              'data:image/svg+xml;base64,',
                              image,
                              '"}'
                          )
                        )
                    )
              )
          );
  }

  function generateSVGofTokenById(uint256 id) /* internal */ public view returns (string memory) {
    bytes32 seed_the = seed[id];
    TartanStripe[9] memory tartan;
    uint tileSize;
    for (uint i = 0; i < tartan.length; i++) {
      // for (uint j = 0; j < 3; j++) {
        tartan[i].color = bytes3(bytes.concat(seed_the[i+0], seed_the[i+1], seed_the[i+2]));
      // }
    }
    uint40 seed_sizes = uint40(bytes5(bytes.concat(seed_the[27], seed_the[28], seed_the[29], seed_the[30], seed_the[31])));
    // TODO limit sizes to 10-70, and add central pivot
    for (uint i = 0; i < tartan.length; i++) {
      tartan[i].size = uint8((1 + seed_sizes % 7) * 10);
      tileSize += tartan[i].size;
      seed_sizes = seed_sizes >> 1;
    }
    console.log("`tileSize` is:", tileSize);

    string memory svgDefs = '<defs><pattern id="pattern" x="0" y="0" width="8" height="8" patternUnits="userSpaceOnUse"><polygon points="0,4 0,8 8,0 4,0" fill="#ffffff"></polygon><polygon points="4,8 8,8 8,4" fill="#ffffff"></polygon></pattern><mask id="grating" x="0" y="0" width="1" height="1"><rect x="0" y="0" width="100%" height="100%" fill="url(#pattern)"></rect></mask></defs>';

    string memory horizontalStrings; 
    string memory verticalStrings;
    uint accumulatedSize;
    for (uint i = 0; i < tartan.length; i++) {
      string memory rectString; 
      string memory horizontalString;
      string memory verticalString;
      rectString = string.concat('<rect fill="#', tartan[i].color.toColor(), '" ');
      horizontalString = string.concat(rectString, 'width="100%" height="', tartan[i].size.toString(), '" x="0" y="', accumulatedSize.toString(), '" />');
      verticalString   = string.concat(rectString, 'width="', tartan[i].size.toString(), '" height="100%" x="', accumulatedSize.toString(), '" y="0" />');
      accumulatedSize += tartan[i].size;
      horizontalStrings = string.concat(horizontalStrings, horizontalString);
      verticalStrings    = string.concat(verticalStrings  , verticalString);
      // console.log('hor & vert in cycle', horizontalStrings, verticalStrings);
    }
    // console.log('hor & vert after cycle', horizontalStrings, verticalStrings);

    string memory svg = string(abi.encodePacked(
      '<svg viewBox="0 0 ', tileSize.toString(), ' ', tileSize.toString(),'" width="', tileSize.toString(), '" height="', tileSize.toString(), '" x="0" y="0" xmlns="http://www.w3.org/2000/svg">',
        svgDefs,
        '<g id="horizontalStripes">',
          horizontalStrings,
        '</g>',
        '<g id="verticalStripes" mask="url(#grating)">',
          verticalStrings,
        '</g>',
      '</svg>'
    ));

    // console.log('result `svg`', svg);

    return svg;
  }

  // Visibility is `public` to enable it being called by other contracts for composition.
  function renderTokenById(uint256 id) public view returns (string memory) {
    string memory render = string(abi.encodePacked(
      '<g id="eye1">',
          '<ellipse stroke-width="3" ry="29.5" rx="29.5" id="svg_1" cy="154.5" cx="181.5" stroke="#000" fill="#fff"/>',
          '<ellipse ry="3.5" rx="2.5" id="svg_3" cy="154.5" cx="173.5" stroke-width="3" stroke="#000" fill="#000000"/>',
        '</g>',
        '<g id="head">',
          '<ellipse fill="#',
          color[id].toColor(),
          '" stroke-width="3" cx="204.5" cy="211.80065" id="svg_5" rx="',
          chubbiness[id].toString(),
          '" ry="51.80065" stroke="#000"/>',
        '</g>',
        '<g id="eye2">',
          '<ellipse stroke-width="3" ry="29.5" rx="29.5" id="svg_2" cy="168.5" cx="209.5" stroke="#000" fill="#fff"/>',
          '<ellipse ry="3.5" rx="3" id="svg_4" cy="169.5" cx="208" stroke-width="3" fill="#000000" stroke="#000"/>',
        '</g>'
      ));

    return render;
  }

  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
      if (_i == 0) {
          return "0";
      }
      uint j = _i;
      uint len;
      while (j != 0) {
          len++;
          j /= 10;
      }
      bytes memory bstr = new bytes(len);
      uint k = len;
      while (_i != 0) {
          k = k-1;
          uint8 temp = (48 + uint8(_i - _i / 10 * 10));
          bytes1 b1 = bytes1(temp);
          bstr[k] = b1;
          _i /= 10;
      }
      return string(bstr);
  }
}
