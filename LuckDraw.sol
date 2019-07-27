pragma solidity ^0.4.17;

import './Upgradeable.sol';
import './Ownable.sol';
import './CBCToken.sol';
import './SafeMath.sol';

contract LuckDraw is Upgradeable, Ownable {
    using SafeMath for uint256;

    address public tokenContractAddress;
    bool public initial;

    uint256 public drawNo;
    bool public gameState;
    uint256 public beginTime;
    uint256 public endTime;
    uint256 public lastEndNumber;
    uint256 public valueOfPerNumber;
    uint256 public beginIndex;
    uint256 public endIndex;
    uint256[] public gameRecord;
    uint256 public endNumberRecord;

    event Init(address logicContractAddress, address sender);
    event NewLuckDraw(address sender, uint256 drawNo, uint256 beginTime, uint256 endTime, uint256 valueOfPerNumber, uint256 beginIndex);
    event Draw(address indexed player, uint256 indexed drawNo, uint256 beginNumber, uint256 endNumber, uint256 timestamp);
    event EndLuckDraw(address sender, uint256 drawNo, uint256 finishIndex, uint256 endIndex);

    function LuckDraw() {

    }

    function init() public {
        require(initial == false);

        if (addressInOwnerList(msg.sender) == false) {
            ownerList.push(msg.sender);
            AddNewOwner(msg.sender, ownerList.length);
        }

        initial = true;
        Init(target, msg.sender);
    }

    function setInitial(bool init) onlyOwner public {
        initial = init;
    }

    function upgrade(address targetAddress) onlyOwner public {
        require(Upgradeable(targetAddress).canUpgrade());
        target = targetAddress;
        Upgrade(msg.sender, target);
    } 

    function beginLuckDraw(uint256 gameBeginTime, uint256 gameEndTime, uint256 perNumberCost) onlyOwner public {
        require(gameBeginTime < gameEndTime && now <= gameBeginTime && gameState == false && beginIndex == endIndex);

        drawNo++;
        beginTime = gameBeginTime;
        endTime = gameEndTime;
        lastEndNumber = 1;
        valueOfPerNumber = perNumberCost;
        gameState = true;
        endNumberRecord = 1;

        NewLuckDraw(msg.sender, drawNo, beginTime, endTime, valueOfPerNumber, beginIndex);
    }

    function draw(address player, uint256 value) onlyTokenContract public {
        require(gameState == true && now >= beginTime && now <= endTime);

        if (value < valueOfPerNumber || value % valueOfPerNumber != 0) {
            throw;
        }
        
        uint256 beginNumber = lastEndNumber;
        lastEndNumber = lastEndNumber.add(value.div(valueOfPerNumber));
        uint256 record = encodeRecord(drawNo, lastEndNumber, player);
        gameRecord.push(record);
        endIndex++;

        Draw(player, drawNo, beginNumber, lastEndNumber, now);        
    }

    /**
    * count为了避免gas不足, 一次操作账户个数
    * count = 0 : 所有操作一次做完
    */
    function endLuckDraw(uint256 count) onlyOwner public {
        require( (now > endTime) && (gameState == true) );
        
        uint256 endLoop;
        uint256 drawNumber;
        uint256 endNumber;
        uint256 value;
        address player;
        if (count == 0 || beginIndex + count > endIndex) {
            endLoop = endIndex;
        } else {
            endLoop = beginIndex + count;
        }

        for (uint256 i = beginIndex; i < endLoop; i++) {
            (drawNumber, endNumber, player) = decodeRecord(gameRecord[i]);
            value = (endNumber.sub(endNumberRecord)).mul(valueOfPerNumber);
            endNumberRecord = endNumber;
            CBCToken(tokenContractAddress).transfer(player, value);
        }
        beginIndex = endLoop;

        if (endLoop == endIndex) {
            gameState = false;
        }

        EndLuckDraw(msg.sender, drawNumber, endLoop, endIndex);
    }

    function encodeRecord(uint256 drawNumber, uint256 endNumber, address player) view public returns (uint256 record) {
        record = record | uint256(player);
        record = record | (endNumber & 0xffffffffffffffff) << 160;
        record = record | (drawNumber & 0xffffffff) << 224;
        return;
    }

    function decodeRecord(uint256 record) public view returns(uint256 drawNumber, uint256 endNumber, address player) {
        player = address( record & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff );
        endNumber =     ( record & 0x00000000ffffffffffffffff0000000000000000000000000000000000000000 ) >> 160;
        drawNumber =    ( record & 0xffffffff00000000000000000000000000000000000000000000000000000000 ) >> 224;
        return;
    }

    function setTokenContractAddress(address tokenContract) onlyOwner public {
        require(tokenContract != 0x0);
        tokenContractAddress = tokenContract;
    } 

    modifier onlyTokenContract {
        require(msg.sender == tokenContractAddress);
        _;
    }   
}