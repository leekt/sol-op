# sol-op

`sol-op` is a Solidity library that allows developers to interact with the Bundler API directly from their Solidity contracts, without the need to switch context to JavaScript or TypeScript. This library leverages "surl," a Solidity HTTP request library, and Foundry's native JSON parsing library, stdJson, to facilitate seamless communication with the Bundler API.

## Features

- Send userOp transactions to the Bundler API using Solidity
- No need to switch between Solidity and JavaScript/TypeScript
- Built-in support for ZeroDev, with easy extensibility for other bundlers
- Utilizes the "surl" library for making HTTP requests from Solidity
- Leverages Foundry's stdJson library for efficient JSON parsing

## Installation

1. Install sol-op:
   ```
   forge install leekt/sol-op
   ```

## Contributing

We welcome contributions to `sol-op`! If you'd like to contribute, please follow these steps:

1. Fork the repository
2. Create a new branch for your feature or bug fix
3. Make your changes and commit them with descriptive commit messages
4. Push your changes to your fork
5. Submit a pull request to the main repository

Please ensure that your code adheres to the project's coding standards and includes appropriate tests.

## License

`sol-op` is released under the [MIT License](./LICENSE).

## Acknowledgements

- [surl](https://github.com/memester-xyz/surl) - Solidity HTTP request library
- [forge-std](https://github.com/foundry-rs/forge-std) - Foundry's standard library for Solidity
- [ZeroDev](https://zerodev.app/) - Decentralized transaction infrastructure for Ethereum

## Contact

If you have any questions, suggestions, or feedback, please feel free to reach out to the maintainers at [leekt216@gmail.com](mailto:leekt216@gmail.com).

Happy coding with `sol-op`!

-this is AI generated markdown-
