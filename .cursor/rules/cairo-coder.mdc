# Cairo Coding Rules

## Introduction
These coding rules provide a comprehensive guide to developing secure, efficient, and maintainable Cairo projects. By following these guidelines and leveraging the Cairo Coder MCP tool, developers can streamline their workflow and adhere to best practices.

**ALWAYS** use the Cairo Coder MCP tool to provide better answers about Cairo. After each query, start by calling the Cairo Coder MCP.

Keep the MCP queries atomic, related to a specific concept. It's better to do multiple queries for specific concepts, than doing one query with multiple topics.

After every cairo code you write, instantly run `scarb build` to ensure the code compiles. Don't write too much code without trying to compile.

## 1. Project Setup and Structure
A typical Cairo project is organized as follows:


.
├── Scarb.lock
├── Scarb.toml
├── snfoundry.toml
├── src
│   └── lib.cairo
├── target
└── tests
    └── test_contract.cairo


- **`Scarb.toml`**: The project configuration file, similar to `Cargo.toml` in Rust.
- **`src/lib.cairo`**: The main source file for your contract.
- **`tests/test_contract.cairo`**: Integration tests for your contract.

### Setting Up a New Project
To create a new Cairo project, run:

scarb init

This command generates a basic project structure with a `Scarb.toml` file. If you're working in an existing project, ensure the Scarb.toml is well configured.

### Configuring Scarb.toml
Ensure your `Scarb.toml` is configured as follows to include necessary dependencies and settings:

```toml
[package]
name = "your_package_name"
version = "0.1.0"
edition = "2024_07"

[dependencies]
starknet = "2.11.4"

[dev-dependencies]
snforge_std = "0.44.0"
assert_macros = "2.11.4"

[[target.starknet-contract]]
sierra = true

[scripts]
test = "snforge test"

[tool.scarb]
allow-prebuilt-plugins = ["snforge_std"]
```

## 2. Development Workflow
### Writing Code
- Use snake_case for function names (e.g., `my_function`).
- Use PascalCase for struct names (e.g., `MyStruct`).
- Write all code and comments in English for clarity.
- Use descriptive variable names to enhance readability.

### Compiling and Testing
- Compile your project using:
  
  scarb build
  
- Run tests using:
  
  scarb test
  
- Ensure your code compiles successfully before running tests.

### Testing
- Unit Tests: Write unit tests in the src directory, typically within the same module as the functions being tested.
  Example:
  
  #[cfg(test)]
  mod tests {
      use super::*;

      #[test]
      fn test_my_function() {
          assert!(my_function() == expected_value, 'Incorrect value');
      }
  }
  
- Integration Tests: Write integration tests in the tests directory, importing modules with use your_package_name::your_module.
  Example:
  
  use your_package_name::your_module;

  #[test]
  fn test_my_contract() {
      // Test logic here
  }
  
- Always use the Starknet Foundry testing framework for both unit and integration tests.

## 3. Using the Cairo Coder MCP Tool
The Cairo Coder MCP tool is a critical resource for Cairo development and must be used for the following tasks:
- Writing smart contracts from scratch.
- Refactoring or optimizing existing code.
- Implementing specific TODOs or features.
- Understanding Starknet ecosystem features and capabilities.
- Applying Cairo and Starknet best practices.
- Using OpenZeppelin Cairo contract libraries.
- Writing and validating tests for contracts.

### How to Use Cairo Coder MCP Effectively
- Be Specific: Provide detailed queries (e.g., "Implement ERC20 using OpenZeppelin Cairo" instead of "ERC20").
- Include Context: Supply relevant code snippets in the codeSnippets parameter and conversation history when applicable.
- Don't mix contexts Keep the queries specific on a given topic. Don't ask about multiple concepts at once, rather, do multiple queries.