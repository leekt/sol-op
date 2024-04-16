// SPDX-License-Identifier : MIT

/// @dev copy pasted from eth-infinitism
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}

struct RPCJson {
    uint256 id;
    string jsonrpc;
    string result;
}

struct RPCError {
    string error;
    string jsonrpc;
}

struct UserOperationReceipt {
    bytes32 hash;
}

struct GasEstimationResult {
    uint256 callGasLimit;
    uint256 paymasterPostOpGasLimit;
    uint256 paymasterVerificationGasLimit;
    uint256 preVerificationGas;
    uint256 verificationGasLimit;
}

struct GasPrice {
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
}

struct GasPriceResult {
    GasPrice slow;
    GasPrice standard;
    GasPrice fast;
}
// bundler 0.7 userOp
//  "params": [
//    {
//      sender, // address
//      nonce, // uint256
//      factory, // address
//      factoryData, // bytes
//      callData, // bytes
//      callGasLimit, // uint256
//      verificationGasLimit, // uint256
//      preVerificationGas, // uint256
//      maxFeePerGas, // uint256
//      maxPriorityFeePerGas, // uint256
//      paymaster, // address
//      paymasterVerificationGasLimit, // uint256
//      paymasterPostOpGasLimit, // uint256
//      paymasterData, // bytes
//      signature // bytes
//    },
