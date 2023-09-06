---
date:
  created: 2022-12-07
authors:
 - joshooaj
categories:
  - PowerShell
  - Usability
links:
  - Download Get-ParentProcess.ps1: blog/posts/ArgumentCompleters/Get-ParentProcess.ps1
---

# Your users deserve argument completers

## Introduction

One of the things I love about PowerShell is the focus on usability and
discoverability. The PowerShell team, and the community, have invested _so much_
into reducing friction and accelerating your workflow. Argument completers are
one of the tools available to you, and you should consider adding them to your
projects if you aren't doing so already.

<!-- more -->

An argument completer is a scriptblock that you can associate with a named
parameter on one or more commands using the [`Register-ArgumentCompleter`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/register-argumentcompleter?view=powershell-7.3) cmdlet.
Then, when a user types that command followed by the parameter name, the
argument completer is invoked. The completer receives information about the
command, parameter, the characters already entered by the user (if any), along
with a hashtable with the names and values of any other parameters the user has
specified so far for that command.

With this information, you can then provide the user with a list of completions.
As an example, when you type `Get-ChildItem -` and then press `TAB` or
`CTRL+Space`, you will get a list of files and folders in the current directory.
And if you type the first few letters of the path you want, the list of argument
completions narrows down to only those paths beginning with those few letters.

I don't think it can be overstated how much it improves the user experience and
accelerates people when argument completion is implemented everywhere it makes
sense. This is a feature of PowerShell that I wasn't aware of when I first
started to build the MilestonePSTools module and in the last year or so I have
started adding them wherever I can.

The jury is still out on how much this is appreciated by MilestonePSTools users
but even if I'm the only one who appreciates them, it's still a win because they
improve my quality, enable me to work faster, and reduce frustration and
fatigue.

## Introducing Get-ParentProcess

Let's start by defining a new function called `Get-ParentProcess` which will
accept either a process name, or ID, and return a `[pscustomobject]` with the
name and ID of the original process, and the name and ID of the parent process.
Why? Because this would be a useful function for me so why not? 😁

```powershell linenums="1"
--8<-- "blog/posts/ArgumentCompleters/Get-ParentProcess.ps1::84"
```

Go ahead and try this function out by copying and pasting it into a PowerShell,
terminal then call it using `Get-ParentProcess -Id $PID`. It should look a bit
like this...

```powershell
Get-ParentProcess -Id $PID

Name          Id ParentName      ParentId
----          -- ----------      --------
powershell 18468 WindowsTerminal    27428
```

Now, try typing `Get-ParentProcess -Name ` and press `TAB`. Chances are PowerShell
will fall back to using a file path completer and you'll see something like
".\something", which isn't terribly useful. And you'll find the same is true with
`Get-ParentProcess -Id `, even though PowerShell knows that the parameter type
for `Id` is `[int]`.

Wouldn't it be nice if the right values were automatically available to select
from? Well, technically since this function accepts processes as pipeline input
through the `InputObject` parameter, you can use `Get-Process -Name ` and then
pipe to `Get-ParentProcess`. But lets make some argument completers anyway!

## Argument completer for "Name"

First I'll introduce the argument completer for the `Name` parameter. I decided
that the completions for this argument should be de-duplicated in case there are
multiple matching processes with the same name, and that the completions should
be surrounded with single quotes if the name contains any spaces.

```powershell linenums="1"
--8<-- "blog/posts/ArgumentCompleters/Get-ParentProcess.ps1:85:103"
```

The `CommandName` and `ParameterName` parameters and values provided to
`Register-ArgumentCompleter` are self-explanatory but it's worth noting that you
can specify multiple command names at once, and even use wildcards. So if you
have multiple cmdlets with the same parameter names, and it makes sense to use
the same completion for each of them, you only need to register the completer
once.

The scriptblock begins with a `param()` declaration with 5 arguments. If you
don't include a `param()` declaration, then those arguments will be available
in the `$args` automatic variable. In this relatively simple use case, we only
need the value from `$wordToComplete`, but here's a quick breakdown of each
argument...

`$commandName`

:   The full name of the command for which the completer has been invoked.

`$parameterName`

:   The name of the parameter for which completion is being requested. This may
    seem strange since you can only specify a single parameter name with
    `Register-ArgumentCompleter` but there's nothing stopping you from storing
    the scriptblock in a variable and re-using it across different commands and
    even different parameter names. Since the scriptblock will receive the
    parameter name, you could leverage that to stay "DRY" - as in, [Don't Repeat
    Yourself](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) by entering
    the same, or very similar code many times.

`$wordToComplete`

:   Either an empty string or one or more characters. If there are single or
    double quotes at the start and/or end of the word, they will be present in
    the value of this variable.

`$commandAst`

:   This is an "abstract syntax tree" which is an abstract representation of
    the command that the user is preparing to run, including the string content
    of the entire pipeline. I have not waded into the deep waters of abstract
    syntax trees yet, but there is great strength in being able to "look around"
    the command being typed by the user. I recommend using the debugger to step
    _into_ an argument completer scriptblock sometime so you can explore this
    argument at runtime.

`$fakeBoundParameters`

:   A hashtable where the keys are the other parameters, if any, that the user
    has specified for the same command. If the values the completer should
    return might be modified by the presence or value of another parameter, this
    enables you to augment those results accordingly. For example, if
    `Get-ChildItem -Directory -Path ` has been typed, it doesn't make sense for
    PowerShell to suggest any file names. The completions for `Path` should be
    exclusively directories. But there's no _guarantee_ that when the user runs
    the command, any of these "fake bound parameters" will still be present.

After the `param()` declaration, a short regular expression is used to check
whether `$wordToComplete` begins with either a single, or a double quote. If it
does, then whatever that first character is will be trimmed from both the front
and end of the string. That way we don't end up searching for a process named
"'note'pad" on accident.

Finally, we invoke `Get-Process` with our `$wordToComplete` with a wildcard
character appended on the end to find all processes that start with the characters
we have so far. And if the user hasn't supplied any characters, then all processes
will be a match. The `Select-Object Name -Unique` part will select the name from
all the results, but only pass the same name to `Foreach-Object` once. We don't
want to return 100 copies of the string "firefox" as argument completion
suggestions - one is enough.

All that is left is to return the matching process name(s), and inside the
`Foreach-Object` scriptblock we take care to wrap the name in single quotes before
returning it if the name contains any spaces. If we don't wrap those names in
quotes then it will be typed for the user exactly as-is, and result in an error
if they don't notice and correct it. It doesn't matter if you wrap strings with
single or double quotes in this case - I choose single quotes whenever I know
I won't be using string-interpolation like `"Hello $Name"`.

## Argument completer for "Id"

The argument completer for the `Id` parameter is very similar to the one for the
`Name` parameter. The big difference is that we are expecting the value to be an
integer, so we need to do a little validation first. On the up-side, we can
simplify how we return the values in the end, because there's no need to wrap
the values with quotes.

```powershell linenums="1"
--8<-- "blog/posts/ArgumentCompleters/Get-ParentProcess.ps1:104:"
```

We start by attempting to coerce the string value of `$wordToComplete` into an
integer. If `$wordToComplete` is null or empty, then the value of `$id` will be
zero. If it is a string like "100", then the value of `$id` will be an integer
of that value. And if `$wordToComplete` has one or more letters or other
non-numberic characters, then `$id` will be null, and we shouldn't return any
completions.

Now, we either need to get _all_ processes in the event the user hasn't entered
any digits yet, or we need to get all processes with a process ID that _begins_
with the digits provided by the user. At this point, if the user hasn't entered
any digits, the value of `$id` is actually "0" because a null, or empty string
will be cast to an integer as the value "0". But we don't want process ID 0 in
this case, we want all processes. So before we call `Get-Process`, we set `$id`
to `$null` if `$wordToComplete` is null or whitespace.

Finally, we can call Get-process, and then filter the results down with a short
regular expression where only the processes with an ID beginning with the value
of `$id` may pass.

## The final result

Here is the full cmdlet with the argument completers. Copy and paste this into
your terminal and have a play with the `TAB` and `CTRL+Space` list completion.
Even better - copy and paste this into VSCode, tinker with the completers, and
see how it changes the user experience. Then use the debugger to step _into_ the
completer and explore the `$commandAst` argument to see how you might be able
to use it in your projects.

```powershell linenums="1"
--8<-- "blog/posts/ArgumentCompleters/Get-ParentProcess.ps1"
```
