import {PackedUserOperation, SponsorUserOpResult} from "../Structs.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {slice} from "./BytesLib.sol";
import {GasPrice} from "../Structs.sol";

library UserOperationLib {
    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    function encode(PackedUserOperation memory userOp) internal pure returns (bytes memory ret) {
        address sender = userOp.sender;
        uint256 nonce = userOp.nonce;
        bytes32 hashInitCode = keccak256(userOp.initCode);
        bytes32 hashCallData = keccak256(userOp.callData);
        bytes32 accountGasLimits = userOp.accountGasLimits;
        uint256 preVerificationGas = userOp.preVerificationGas;
        bytes32 gasFees = userOp.gasFees;
        bytes32 hashPaymasterAndData = keccak256(userOp.paymasterAndData);

        return abi.encode(
            sender,
            nonce,
            hashInitCode,
            hashCallData,
            accountGasLimits,
            preVerificationGas,
            gasFees,
            hashPaymasterAndData
        );
    }

    function hash(PackedUserOperation memory userOp) internal pure returns (bytes32) {
        return keccak256(encode(userOp));
    }

    function applyGasPrice(PackedUserOperation memory op, GasPrice memory gasPrice) internal pure {
        op.gasFees = bytes32(abi.encodePacked(uint128(gasPrice.maxPriorityFeePerGas), uint128(gasPrice.maxFeePerGas)));
    }

    function applySponsorResult(PackedUserOperation memory op, SponsorUserOpResult memory res) internal pure {
        op.preVerificationGas = res.preVerificationGas;
        op.paymasterAndData = abi.encodePacked(
            res.paymaster,
            uint128(res.paymasterVerificationGasLimit),
            uint128(res.paymasterPostOpGasLimit),
            res.paymasterData
        );
        op.accountGasLimits = bytes32(abi.encodePacked(uint128(res.verificationGasLimit), uint128(res.callGasLimit)));
    }

    function serializePackedOp(PackedUserOperation memory op) internal returns (string memory json) {
        string memory obj = "op";
        //vm.serializeJson(obj, '{"paymaster":null,"paymasterVerificationGasLimit":null,"paymasterPostOpGasLimit":null,"paymasterData":null}');
        vm.serializeAddress(obj, "sender", op.sender);
        vm.serializeUint(obj, "nonce", op.nonce);
        if (op.initCode.length > 0) {
            vm.serializeAddress(obj, "factory", address(bytes20(slice(op.initCode, 0, 20))));
            vm.serializeBytes(obj, "factoryData", slice(op.initCode, 20, op.initCode.length - 20));
        } else {
            //vm.serializeBytes(obj, "factory", hex"");
            //vm.serializeBytes(obj, "factoryData", hex"");
        }
        vm.serializeBytes(obj, "callData", op.callData);
        vm.serializeUint(obj, "callGasLimit", uint128(uint256(op.accountGasLimits)));
        vm.serializeUint(obj, "verificationGasLimit", uint128(uint256(op.accountGasLimits >> 128)));
        vm.serializeUint(obj, "preVerificationGas", op.preVerificationGas);
        vm.serializeUint(obj, "maxFeePerGas", uint128(uint256(op.gasFees)));
        vm.serializeUint(obj, "maxPriorityFeePerGas", uint128(uint256(op.gasFees >> 128)));
        if (op.paymasterAndData.length > 0) {
            vm.serializeAddress(obj, "paymaster", address(bytes20(slice(op.paymasterAndData, 0, 20))));
            vm.serializeUint(obj, "paymasterVerificationGasLimit", uint128(bytes16(slice(op.paymasterAndData, 20, 16))));
            vm.serializeUint(obj, "paymasterPostOpGasLimit", uint128(bytes16(slice(op.paymasterAndData, 36, 52))));
            vm.serializeBytes(obj, "paymasterData", slice(op.paymasterAndData, 52, op.paymasterAndData.length - 52));
        } else {
            //vm.serializeBytes(obj, "paymaster", hex"");
            //vm.serializeUint(obj, "paymasterVerificationGasLimit", 0);
            //vm.serializeUint(obj, "paymasterPostOpGasLimit", 0);
            //vm.serializeBytes(obj, "paymasterData", hex"");
        }
        json = vm.serializeBytes(obj, "signature", op.signature);
    }
}
