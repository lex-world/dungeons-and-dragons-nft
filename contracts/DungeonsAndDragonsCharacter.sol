// contracts/DungeonsAndDragonsCharacter.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

//https://oneclickdapp.com/boxer-santana/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IBattles.sol";

contract DungeonsAndDragonsCharacter is ERC721, VRFConsumerBase, Ownable {
    using SafeMath for uint256;
    using Strings for string;

    bool battlesSet = false;
    address public battlesContract;

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    address public VRFCoordinator = 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B;
    address public LinkToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;

    struct Character {
        uint256 strength;
        uint256 dexterity;
        uint256 constitution;
        uint256 intelligence;
        uint256 wisdom;
        uint256 charisma;
        uint256 experience;
        string name;
    }

    Character[] public characters;

    mapping(bytes32 => string) requestToCharacterName;
    mapping(bytes32 => address) requestToSender;
    mapping(bytes32 => uint256) requestToTokenId;

    /**
     * Constructor inherits VRFConsumerBase
     *
     * Network: Rinkeby
     * Chainlink VRF Coordinator address: 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B
     * LINK token address:                0xa36085f69e2889c224210f603d836748e7dc0088
     * Key Hash: 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311
     */
    constructor()
        public
        VRFConsumerBase(VRFCoordinator, LinkToken)
        ERC721("DungeonsAndDragonsCharacter", "D&D")
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10**18; // 0.1 LINK
    }

    function setBattlesContract(address _battles) external onlyOwner {
        require(
            battlesSet == false,
            "The battles contract can only be set once"
        );
        battlesContract = _battles;
        battlesSet = true;
    }

    modifier onlyBattlesContract() {
        require(msg.sender == battlesContract); // If it is incorrect here, it reverts.
        _; // Otherwise, it continues.
    }

    function requestNewRandomCharacter(
        uint256 userProvidedSeed,
        string memory name
    ) public returns (bytes32) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        bytes32 requestId = requestRandomness(keyHash, fee, userProvidedSeed);
        requestToCharacterName[requestId] = name;
        requestToSender[requestId] = msg.sender;
        return requestId;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomNumber)
        internal
        override
    {
        uint256 newId = characters.length;
        uint256 strength = ((randomNumber % 100) % 18);
        uint256 dexterity = (((randomNumber % 10000) / 100) % 18);
        uint256 constitution = (((randomNumber % 1000000) / 10000) % 18);
        uint256 intelligence = (((randomNumber % 100000000) / 1000000) % 18);
        uint256 wisdom = (((randomNumber % 10000000000) / 100000000) % 18);
        uint256 charisma = (((randomNumber % 1000000000000) / 10000000000) %
            18);
        uint256 experience = 0;

        characters.push(
            Character(
                strength,
                dexterity,
                constitution,
                intelligence,
                wisdom,
                charisma,
                experience,
                requestToCharacterName[requestId]
            )
        );
        _safeMint(requestToSender[requestId], newId);
    }

    /**
     * this is hardcoded and centralized for now
     * but you'd want to call a network of chainlink nodes
     */
    function requestBattleResults(uint256 tokenId)
        public
        returns (bytes32 requestId)
    {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        require(battlesSet == true, "No battles contract set yet!");
        IBattles(battlesContract).requestBattleResults(tokenId);
    }

    function updateExperience(uint256 tokenId, uint256 experience)
        external
        onlyBattlesContract
    {
        characters[tokenId].experience =
            characters[tokenId].experience +
            experience;
    }

    function getLevel(uint256 tokenId) public view returns (uint256) {
        return sqrt(characters[tokenId].experience);
    }

    function getCharacterOverView(uint256 tokenId)
        public
        view
        returns (
            string memory,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            characters[tokenId].name,
            characters[tokenId].strength + characters[tokenId].dexterity + characters[tokenId].constitution + characters[tokenId].intelligence + characters[tokenId].wisdom + characters[tokenId].charisma,
            getLevel(tokenId),
            characters[tokenId].experience
        );
    }

    function getCharacterStats(uint256 tokenId)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            characters[tokenId].strength,
            characters[tokenId].dexterity,
            characters[tokenId].constitution,
            characters[tokenId].intelligence,
            characters[tokenId].wisdom,
            characters[tokenId].charisma,
            characters[tokenId].experience
        );
    }

    function sqrt(uint256 x) internal view returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}