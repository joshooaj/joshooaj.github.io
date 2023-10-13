---
draft: true
date:
  created: 2023-09-09
authors:
 - joshooaj
categories:
  - PowerShell
---

# Using custom attributes in PowerShell

## Introduction

I've been working with with custom attributes in PowerShell for the last few months and they can be _incredibly_ useful in the right circumstances. You know those handy built-in argument validators like `#!powershell [ValidateRange(1, 10)]`, `#!powershell [ValidateSet('Apples', 'Oranges')]`, or `#!powershell [ValidateNotNullOrEmpty()]` that you get for free? You can make your own custom versions, and it can really level up your module quality and even improve your documentation. Let's start with what they are, and how they work.

<!-- more -->

## What are attributes?

Attributes are a feature of many languages which allow the developer to attach extra information to an object. These attributes
are available at runtime using another language feature called "reflection" which enables an application to inspect itself
_while it's running_. You've probably encountered these in PowerShell if you've ever seen or written a cmdlet or
advanced function. For example, `[CmdletBinding()]`, `[Parameter()]`, and `[ValidateNotNullOrEmpty()]` are all attributes
which help the PowerShell runtime find your commands, and bind or validate parameters when those commands are used.

An attribute can have its own positional, or named parameters, and those properties can be used in different ways. For instance,
when you add an attribute like `[ValidateSet('Option1', 'Option2')]` to a parameter in a PowerShell function, the PowerShell
runtime uses that information during parameter binding when that function is called. If the value for the parameter isn't
either "Option1" or "Option2", the PowerShell runtime will throw a `ParameterBindingValidationException` exception with
a _really informative_ error message like...

```plaintext
Cannot validate argument on parameter 'YourParameterName'. The argument "Option3" does not belong
to the set "Option1,Option2" specified by the ValidateSet attribute. Supply an argument that is in the set
and then try the command again.
```

Adding a little extra information to your code using attributes allows PowerShell to enhance the user experience for anyone
using your scripts, modules, tools, etc. And they aren't just used to add easy parameter validation and clear error messages.
They can also be used to automatically generate or augment documentation. For instance, if you use `[ValidateSet()]`, in the
commands within a PowerShell module, the platyps module will discover the valid values and include them in your docs automatically!

## Argument validation

### with ValidateScript

Before I talk about the `ValidateArgumentsAttribute` base class and other uses for custom attributes in PowerShell, I should introduce
the [ValidateScript()] attribute. This is a super flexible argument validation attribute you can use right out of the box to
perform any kind of validation you want on an argument. For instance, what if you have a function with a parameter named
"LuckyNumber" which needs to be an integer greater than 0, and only divisible by 7?

There are three constraints:

1. The type must be `[int]`
2. The range is 0 to `[int]::MaxValue` or 2147483647
3. The value must be divisible by 7

The first two are easy enough to check using `[ValidateRange()]` and specifying the `[int]` type when declaring the function
parameter, but [ValidateDivisibleBy(7)] isn't a thing. You'll need to write your own code _somewhere_ to validate divisibility
of values passed to the LuckyNumber parameter. I imagine most of the time people would choose to inspect the value toward
the top of the begin, or process blocks of the function. But you could also do this with the `[ValidateScript()]` attribute.
Here's what both options, and their validation errors might look like:

=== "Without ValidateScript"
    ```powershell linenums="1"
    function Do-Something {
        [CmdletBinding()]
        param(
            [Parameter()]
            [ValidateRange(0, [int]::MaxValue)]
            [int]
            $LuckyNumber
        )

        process {
            # We only know LuckyNumber is an integer >= 0 so we need to test it before we continue.
            if ($LuckyNumber % 7) {
                throw "The number $LuckyNumber is not divisible by 7."
            }

            $LuckyNumber
        }
    }

    Do-Something -LuckyNumber 13

    <# OUTPUT
        The number 13 is not divisible by 7.
        At line:13 char:17
        + ...                throw "The number $LuckyNumber is not divisible by 7."
        +                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            + CategoryInfo          : OperationStopped: (The number 13 is not divisible by 7.:String) [], RuntimeExcepti
        on
            + FullyQualifiedErrorId : The number 13 is not divisible by 7.
    #>
    ```

=== "With ValidateScript"
    ```powershell linenums="1"
    function Do-Something {
        [CmdletBinding()]
        param(
            [Parameter()]
            [ValidateRange(0, [int]::MaxValue)]
            [ValidateScript({
                if ($_ % 7) {
                    throw "The number $_ is not divisible by 7."
                }
                $true
            })]
            [int]
            $LuckyNumber
        )

        process {
            # We know LuckyNumber passed all three constraints already, so no further testing is needed.
            $LuckyNumber
        }
    }

    Do-Something -LuckyNumber 13

    <#
        Do-Something : Cannot validate argument on parameter 'LuckyNumber'. The number 13 is not divisible by 7.
        At line:1 char:32
        +     Do-Something -LuckyNumber 13
        +                                ~~
            + CategoryInfo          : InvalidData: (:) [Do-Something], ParameterBindingValidationException
            + FullyQualifiedErrorId : ParameterArgumentValidationError,Do-Something
    #>
    ```

Both options will result with the function throwing an error, and the error messages both provide information about why
the error occurred, but I think the error message from the function using the `[ValidateScript()]` attribute is more clear
and informative. That said, I think the code looks cleaner without that scriptblock sitting up there inside the `param()` block.
I'd be okay with one little messy parameter declaration, but what if I have multiple functions in my module with a LuckyNumber
parameter? I don't want to copy that ugly `[ValidateScript()]` attribute and its scriptblock and use it every time. Even if
I made a `Test-LuckyNumber` function and simply called that within the scriptblock, I still think it makes the code harder
to read and maintain.

### with ValidateArgumentsAttribute

When you have complex validation to perform, or when you might need to do it many times in many functions across your module,
it might make sense to write your own argument validator by sub-classing the ValidateArgumentsAttribute class. All of PowerShell's
`[Validate*()]` attributes are sub-classes of [`System.Management.Automation.ValidateArgumentsAttribute`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.validateargumentsattribute?view=powershellsdk-7.3.0), each with their own implementation of the [`Validate(Object, EngineIntrinsics)`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.validateargumentsattribute.validate?view=powershellsdk-7.3.0#system-management-automation-validateargumentsattribute-validate(system-object-system-management-automation-engineintrinsics))
method where values passed to the parameter get tested. And the PowerShell team made it possible for us to make our
own validation attributes the same way. Here's what the class definition looks like for our custom [ValidateVisibleBy()] attribute:

```powershell linenums="1"
using namespace System.Management.Automation

class ValidateDivisibleBy : ValidateArgumentsAttribute {
    [int]$Divisor

    ValidateDivisibleBy([int]$divisor) {
        $this.Divisor = $divisor
    }

    [void] Validate([object]$object, [EngineIntrinsics]$intrinsics) {
        if ($object % $this.Divisor) {
            $exception = [ValidationMetadataException]::new("The number $object is not divisible by $($this.Divisor)")
            throw $exception
        }
    }
}
```

I admit it's more complex than using `[ValidateScript()]` or simply testing the value and throwing an error inside the body
of the function. But when you perform the same validation across multiple functions and/or maintain the code with other
people, being able to de-duplicate and easily understand the intent of the code is well worth it. Check out how much cleaner
the function looks now with our `[ValidateDivisibleBy()]` attribute:

```powershell linenums="1"
function Do-Something {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [ValidateDivisibleBy(7)]
        [int]
        $LuckyNumber
    )

    process {
        $LuckyNumber
    }
}

Do-Something -LuckyNumber 13

<# Error
    Do-Something : Cannot validate argument on parameter 'LuckyNumber'. The number 13 is not divisible by 7
    At line:32 char:27
    + Do-Something -LuckyNumber 13
    +                           ~~
        + CategoryInfo          : InvalidData: (:) [Do-Something], ParameterBindingValidationException
        + FullyQualifiedErrorId : ParameterArgumentValidationError,Do-Something
#>
```

This attribute can now be re-used in many functions by adding a simple, declarative attribute where needed. The error messages
produced as a result of passing an invalid value are clean and consistent with any other argument validation error.

## Attributes on functions

I used attributes in a somewhat unconventional way with the MilestonePSTools module to add validation on entire functions
and cmdlets. PowerShell facilitates validation of individual parameters during parameter binding by automatically calling
the `Validate(Object, EngineIntrinsics)` method on attributes derived from `ValidateArgumentsAttribute`, but there is no
framework in place to automatically call a `Validate()` method on an attribute applied to the whole command, so I
implemented it by adding a call to `Assert-VmsRequirementsMet` in the `begin {}` block of every cmdlet with a "requirement"
to assert.

This made sense for the MilestonePSTools project because the module wraps Milestone's SDK which includes support
for features available exclusively in the top-tier product version, but it also works on the free edition which lacks
many features. Some commands, like `Get-VmsFailoverGroup` will only work when used while connected to a Milestone system
with the `RecordingServerFailover` feature flag.

--8<-- "abbreviations.md"
