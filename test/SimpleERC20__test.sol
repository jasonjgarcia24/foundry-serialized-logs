// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";

import {SimpleERC20, _INITIAL_SUPPLY_} from "@base/SimpleERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ISimpleERC20Test {
    struct DealData {
        address receiver;
        uint8 giveAmount;
    }

    struct TokenData {
        address token;
        uint256 totalSupply;
        uint256 balanceOfCreator;
        uint256 balanceOfReceiver;
    }
}

interface IReportTest {
    struct ReportData {
        uint8 giveAmount;
        address receiver;
        uint256 balanceOfCreator;
        uint256 balanceOfReceiver;
        address token;
        uint256 totalSupply;
    }
}

library SerializeHelper {
    // Note: The resultant contract address for 'vm' is hard-coded at
    // address(uint160(uint256(keccak256("hevm cheat code"))))), which
    // is 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.

    function serialize(
        uint256 _value,
        string calldata _objectKey,
        string calldata _valueKey
    ) public returns (string memory _serialized) {
        Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        _serialized = vm.serializeUint(_objectKey, _valueKey, _value);
    }

    function serialize(
        address _value,
        string calldata _objectKey,
        string calldata _valueKey
    ) public returns (string memory _serialized) {
        Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        _serialized = vm.serializeAddress(_objectKey, _valueKey, _value);
    }

    function serialize(
        string memory _value,
        string calldata _objectKey,
        string calldata _valueKey
    ) public returns (string memory _serialized) {
        Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        _serialized = vm.serializeString(_objectKey, _valueKey, _value);
    }
}

abstract contract SimpleERC20ReportRecorder is
    CommonBase,
    ISimpleERC20Test,
    IReportTest
{
    using SerializeHelper for *;

    function recordDebtData(
        string memory _outputFile,
        DealData memory _dealData,
        TokenData memory _tokenData
    ) public {
        _outputFile = string(
            abi.encodePacked("./report/", _outputFile, ".json")
        );

        // Read data.
        bytes memory _inputData = readJson(_outputFile);

        // Parse data.
        string memory _outputData = parseJson(
            _inputData,
            _dealData,
            _tokenData
        );

        // Write data.
        vm.writeJson(_outputData, _outputFile);
    }

    function readJson(
        string memory _file
    ) public view returns (bytes memory _fileData) {
        // Read file. If file doesn't exist, return empty bytes.
        try vm.readFile(_file) returns (string memory _fileStr) {
            _fileData = bytes(_fileStr).length > 0
                ? vm.parseJson(_fileStr)
                : new bytes(0);
        } catch (bytes memory) {
            _fileData = new bytes(0);
        }
    }

    function parseJson(
        bytes memory _prevData,
        DealData memory _dealData,
        TokenData memory _tokenData
    ) public returns (string memory _outputData) {
        // Collect all debt data.
        uint256 _dataLength = 32 * 6;
        uint256 _numElements = _prevData.length / _dataLength;
        bytes memory _chunk = new bytes(_dataLength);

        for (uint256 i; i <= _numElements; i++) {
            ReportData memory _reportData;

            // Get previous run's data.
            if (i < _numElements) {
                uint256 _offset = i * _dataLength;

                for (uint256 j; j < _dataLength; j++)
                    _chunk[j] = _prevData[_offset + j];

                _reportData = abi.decode(_chunk, (ReportData));
            }
            // Get new run's data.
            else {
                _reportData = ReportData({
                    receiver: _dealData.receiver,
                    giveAmount: _dealData.giveAmount,
                    token: _tokenData.token,
                    totalSupply: _tokenData.totalSupply,
                    balanceOfCreator: _tokenData.balanceOfCreator,
                    balanceOfReceiver: _tokenData.balanceOfReceiver
                });
            }

            // Package DealData object.
            _reportData.giveAmount.serialize("deal_data", "give_amount");
            string memory _dealDataObj = _reportData.receiver.serialize(
                "deal_data",
                "receiver"
            );

            _dealDataObj.serialize("level_2", "deal_data");

            // Package TokenData object.
            _reportData.balanceOfCreator.serialize(
                "token_data",
                "balance_of_creator"
            );
            _reportData.balanceOfReceiver.serialize(
                "token_data",
                "balance_of_receiver"
            );
            vm.serializeAddress("token_data", "token", _reportData.token);
            string memory _termsObj = _reportData.totalSupply.serialize(
                "token_data",
                "total_supply"
            );

            string memory _level2Obj = _termsObj.serialize(
                "level_2",
                "token_data"
            );

            // Package ReportData object.
            _outputData = _level2Obj.serialize(
                "level_1",
                string(abi.encodePacked("report_run_", vm.toString(i)))
            );
        }
    }
}

contract SimpleERC20Test is
    StdCheats,
    StdAssertions,
    SimpleERC20ReportRecorder
{
    address constant _CREATOR_ =
        address(uint160(uint256(keccak256("simple erc20 creator"))));

    function setUp() public {}

    function testSimpleERC20_Deal(
        address _token,
        DealData memory _dealData
    ) public {
        // Housekeeping.
        vm.assume(uint256(uint160(_token)) > 10);

        // Setup.
        _deploySimpleToken(_token);

        // Test.
        TokenData memory _tokenData = _testDealSimpleToken(
            _token,
            _dealData.receiver,
            uint256(_dealData.giveAmount)
        );

        // Save report.
        if (vm.envOr("RUN_REPORT", false))
            recordDebtData("simple-erc20-deal", _dealData, _tokenData);
    }

    function _deploySimpleToken(address _token) internal {
        vm.label(_token, "FUZZED_SIMPLE_ERC20_TOKEN");
        vm.startPrank(_CREATOR_);
        deployCodeTo("./out/SimpleERC20.sol/SimpleERC20.json", _token);
        vm.stopPrank();
    }

    function _testDealSimpleToken(
        address _token,
        address _receiver,
        uint256 _giveAmount
    ) internal returns (TokenData memory _tokenData) {
        IERC20Metadata _simpleToken = IERC20Metadata(_token);

        // Deal.
        vm.label(_receiver, "SIMPLE_ERC20_RECEIVER");
        deal(_token, _receiver, _giveAmount, true);

        // Get token data.
        _tokenData = TokenData({
            token: _token,
            totalSupply: _simpleToken.totalSupply(),
            balanceOfCreator: _simpleToken.balanceOf(_CREATOR_),
            balanceOfReceiver: _simpleToken.balanceOf(_receiver)
        });

        // Assert.
        assertEq(
            _tokenData.totalSupply,
            _INITIAL_SUPPLY_ + _giveAmount,
            "total supply should be increased"
        );

        assertEq(
            _tokenData.balanceOfCreator,
            _INITIAL_SUPPLY_,
            "balance of creator should be unchanged"
        );

        assertEq(
            _tokenData.balanceOfReceiver,
            _giveAmount,
            "balance of receiver should be equal to give amount"
        );
    }
}
