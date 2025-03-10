# Participant Benefits Digital Asset Contract

This smart contract provides a digital reward system based on non-fungible tokens (NFTs), enabling participants to earn, transfer, and manage assets with tokenized benefits. The contract supports individual and bulk operations, offers detailed access control mechanisms, and ensures the security of asset transactions. It is designed to be used in scenarios where digital assets represent participant rewards or benefits that can be tracked, transferred, and modified.

## Features

- **Asset Creation**: Create individual or multiple assets (NFTs) with associated value.
- **Asset Transfer**: Transfer asset ownership between participants.
- **Asset Deactivation & Reactivation**: Permanently deactivate or restore assets.
- **Asset Value Management**: Modify, increase, decrease, or redeem the value associated with assets.
- **Batch Operations**: Perform bulk asset creation in a single transaction.
- **Access Control**: Administrative functions with restricted access for contract administrators.
- **Security**: Proper validation, access control, and error handling for various asset operations.

## Contract Parameters

- **contract-administrator**: Address of the administrator with special privileges for asset management.
- **bulk-operation-limit**: Maximum number of assets allowed in a bulk operation (set to 100).

## Core Storage

- **digital-asset**: Non-fungible token representing the digital asset.
- **asset-counter**: Counter for asset identification.
- **asset-holder**: Maps each asset to its current holder.
- **asset-value**: Maps each asset to its associated value.
- **deactivated-assets**: Tracks deactivated assets.
- **asset-notes**: Stores additional information about assets.

## Administrative Functions

- **create-single-asset**: Creates a single asset with specified value (admin only).
- **create-multiple-assets**: Creates multiple assets in one transaction (admin only).
- **deactivate-asset**: Permanently deactivates an asset (only the holder can deactivate).
- **transfer-asset**: Transfers asset ownership (only the holder can transfer).
- **modify-asset-value**: Updates the value associated with a specific asset.

## Information Retrieval Functions

- **get-asset-value**: Retrieves the value associated with an asset.
- **get-asset-holder**: Retrieves the current holder of an asset.
- **get-asset-status**: Checks if an asset is deactivated.
- **get-total-assets-created**: Returns the total number of assets created.

## Installation

To deploy this contract, follow these steps:

1. **Install Dependencies**:
    - Ensure you have the required blockchain environment set up (e.g., Algorand or similar).
    - Install smart contract development tools and dependencies.

2. **Deploy Contract**:
    - Use the smart contract deployment tools to deploy this contract to the desired network.

3. **Interact with the Contract**:
    - Use a compatible front-end application or blockchain interface (e.g., web3.js, CLI) to interact with the deployed contract.

## Usage

### Creating a Single Asset

```clojure
(create-single-asset <value>)
```

### Creating Multiple Assets

```clojure
(create-multiple-assets [<value1> <value2> <value3> ...])
```

### Deactivating an Asset

```clojure
(deactivate-asset <asset-id>)
```

### Transferring an Asset

```clojure
(transfer-asset <asset-id> <sender-address> <recipient-address>)
```

### Modifying Asset Value

```clojure
(modify-asset-value <asset-id> <new-value>)
```

## Error Handling

- **Unauthorized Actions**: Errors occur when non-authorized users attempt operations (e.g., transfer or deactivate).
- **Invalid Inputs**: Errors are raised for invalid asset values, exceeding bulk operation limits, and invalid asset operations.

## Contributing

We welcome contributions! If you wish to add new features, improve documentation, or fix bugs, feel free to fork the repository, make changes, and submit a pull request.


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.