# Contributing to Azure Cost Optimization

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Code Standards](#code-standards)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)

---

## 📜 Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the maintainers.

### Our Standards

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other community members

---

## 🤝 How to Contribute

### Ways to Contribute

1. **🐛 Report Bugs** - Found a bug? Open an issue!
2. **💡 Suggest Features** - Have an idea? We'd love to hear it!
3. **📖 Improve Documentation** - Help make our docs better
4. **🔧 Submit Code** - Fix bugs or add new features
5. **🧪 Add Tests** - Help improve test coverage
6. **👀 Review PRs** - Help review pull requests

### Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a feature branch
4. Make your changes
5. Test your changes
6. Submit a pull request

---

## 💻 Development Setup

### Prerequisites

- PowerShell 7.0 or later
- Azure PowerShell modules (Az.Accounts, Az.Compute, Az.MySql)
- Git
- An Azure subscription (for testing)

### Local Setup

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/azure-cost-optimization.git
cd azure-cost-optimization

# Add upstream remote
git remote add upstream https://github.com/3tallah/azure-cost-optimization.git

# Install required modules
Install-Module -Name Az -Scope CurrentUser -Force
Install-Module -Name Pester -Scope CurrentUser -Force
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
```

### Running Tests

```powershell
# Run all tests
Invoke-Pester -Path .\tests\ -Output Detailed

# Run specific test file
Invoke-Pester -Path .\tests\mysql.tests.ps1 -Output Detailed

# Run with code coverage
Invoke-Pester -Path .\tests\ -CodeCoverage .\mysql\*.ps1 -Output Detailed
```

### Code Analysis

```powershell
# Run PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path .\mysql\ -Recurse
Invoke-ScriptAnalyzer -Path .\vm\ -Recurse
```

---

## 📏 Code Standards

### PowerShell Style Guide

1. **Use approved verbs** for function names (Get-, Set-, New-, Remove-, etc.)
2. **Use PascalCase** for function names and parameters
3. **Include comment-based help** for all public functions
4. **Use full cmdlet names** (not aliases) in scripts
5. **Indent with 4 spaces** (not tabs)

### Example Function Structure

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description of the function.
        
    .DESCRIPTION
        Detailed description of what the function does.
        
    .PARAMETER ParameterName
        Description of the parameter.
        
    .EXAMPLE
        Verb-Noun -ParameterName "Value"
        
        Description of what this example does.
        
    .OUTPUTS
        Description of what the function returns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )
    
    # Function logic here
}
```

### Commit Message Format

Use conventional commit messages:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(mysql): add support for Memory Optimized tier
fix(vm): handle VM in deallocated state
docs(readme): add troubleshooting section
```

---

## 🔄 Pull Request Process

### Before Submitting

1. **Update your fork** with the latest upstream changes
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests** and ensure they pass
   ```powershell
   Invoke-Pester -Path .\tests\
   ```

3. **Run code analysis** and fix any issues
   ```powershell
   Invoke-ScriptAnalyzer -Path .\ -Recurse
   ```

4. **Update documentation** if needed

### Submitting a PR

1. Push your branch to your fork
   ```bash
   git push origin feature/my-feature
   ```

2. Open a Pull Request against the `main` branch

3. Fill out the PR template completely

4. Wait for review and address any feedback

### PR Requirements

- [ ] Tests pass
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] Commit messages follow conventions
- [ ] No merge conflicts

---

## 🐛 Reporting Issues

### Before Creating an Issue

1. **Search existing issues** to avoid duplicates
2. **Check the documentation** for answers
3. **Try the latest version** of the scripts

### Bug Report Template

When reporting a bug, please include:

```markdown
**Describe the bug**
A clear description of the bug.

**To Reproduce**
Steps to reproduce:
1. Run '...'
2. With parameters '...'
3. See error

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Environment**
- Azure Region: [e.g., East US]
- PowerShell Version: [e.g., 7.4]
- Az Module Version: [e.g., 11.0]
- Automation Account SKU: [Basic/Free]

**Error Messages**
```
Paste any error messages here
```

**Additional context**
Any other relevant information.
```

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
A clear description of the problem.

**Describe the solution you'd like**
What you want to happen.

**Describe alternatives you've considered**
Other solutions you've thought about.

**Additional context**
Any other relevant information.
```

---

## 🏷️ Labels

We use the following labels to categorize issues and PRs:

| Label | Description |
|-------|-------------|
| `bug` | Something isn't working |
| `enhancement` | New feature or request |
| `documentation` | Documentation improvements |
| `good first issue` | Good for newcomers |
| `help wanted` | Extra attention needed |
| `question` | Further information requested |
| `wontfix` | This will not be worked on |

---

## 📞 Getting Help

- **Questions?** Open a [Discussion](../../discussions)
- **Found a bug?** Open an [Issue](../../issues)
- **Need help?** Check the [Documentation](docs/)

---

## 🙏 Thank You!

Thank you for contributing to Azure Cost Optimization! Your efforts help make this project better for everyone.
