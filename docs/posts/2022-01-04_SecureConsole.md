---
date: 2022-01-04
authors:
 - joshooaj
categories:
  - C#
---

# Securely Reading Passwords from the Console

If you've ever written a console application which requires the user to enter sensitive information like a password or a token, you might have wrestled with concerns of exposing the password in plain text within the console window.

<!-- more -->

I was writing a new console application earlier today after spending most of my time in PowerShell for the last three years, and I found myself wanting to use `Read-Host -AsSecureString`, and remembered how much I take for granted that PowerShell gives us so much for free.

After making sure none of the `Console.Read*` methods baked into .NET would give me what I wanted, I wrote a fairly short `SecureConsole` class with a `SecureConsole.ReadLine()` method along with a `SecureConsole.GetCredential(string message)` method. I wanted to emulate PowerShell's `Get-Credential` since I needed both a username and password.

Here's what I ended up with. The `SecureConsole.ReadLine()` method will...

1. read any non-control character entered by the user
2. append each new `char` to a `System.Security.SecureString`
3. write an asterisk (*) symbol back to the console
4. accept the backspace key and behave as expected

![Demonstration of the console application showing the password obscured with asterisks.](/assets/images/SecureConsoleDemo.gif)

Here's the `SecureConsole` class, and a demo program where I'm calling `SecureConsole.GetCredential()` to prompt the user for their credentials. The password will be recorded as a `SecureString` and then paired with the username to create a `System.Net.NetworkCredential`. For testing purposes, the plain text password from the credential is printed out to verify the text was received properly. Read on after the code sample for details.

```csharp linenums="1" title="program.cs"
using System;
using System.Net;
using System.Security;

namespace SecureConsoleDemo
{
  internal class Program
  {
    static void Main(string[] args)
    {
      while (true)
      {
        Console.Clear();
        var nc = SecureConsole.GetCredential();
        if (nc.UserName == String.Empty)
        {
          break;
        }

        // For testing purposes, your securestring password will be
        // revealed in plain text to verify it was accurately read
        // and control characters properly ignored.
        Console.WriteLine($"You entered '{nc.Password}'");
        Console.WriteLine("Press any key to continue. . .");
        Console.ReadKey(true);
      }
    }
  }

  public static class SecureConsole
  {
    public static NetworkCredential GetCredential()
    {
      return GetCredential(string.Empty);
    }

    public static NetworkCredential GetCredential(string message)
    {
      if (!string.IsNullOrWhiteSpace(message))
      {
        Console.WriteLine(message);
      }
      Console.Write("Username: ");
      var username = Console.ReadLine();

      Console.Write("Password: ");
      var password = SecureConsole.ReadLine();

      return new NetworkCredential(username, password);
    }

    public static SecureString ReadLine()
    {
      var password = new SecureString();
      ConsoleKeyInfo key;
      while ((key = Console.ReadKey(true)).Key != ConsoleKey.Enter)
      {
        if (key.Key == ConsoleKey.Backspace && password.Length > 0)
        {
          Console.Write("\b \b");
          password.RemoveAt(password.Length - 1);
        }
        else if (!char.IsControl(key.KeyChar))
        {
          Console.Write("*");
          password.AppendChar(key.KeyChar);
        }
      }
      Console.Write(Environment.NewLine);
      return password;
    }
  }
}
```

## The main loop

The program is a simple loop where we read from the console until the user enters a credential with a blank user name. Once a credential is entered, the password is printed to the screen and we do it again.

```csharp linenums="9" title="program.cs"
    static void Main(string[] args)
    {
      while (true) // (1)
      {
        Console.Clear();
        var nc = SecureConsole.GetCredential(); // (2)
        if (nc.UserName == String.Empty)
        {
          break;
        }

        // For testing purposes, your securestring password will be
        // revealed in plain text to verify it was accurately read
        // and control characters properly ignored.
        Console.WriteLine($"You entered '{nc.Password}'"); // (3)
        Console.WriteLine("Press any key to continue. . .");
        Console.ReadKey(true); // (4)
      }
    }
```

1. This loop will continue forever, or until we reach the `break;` on line 17 by pressing enter without entering a username.
2. The `GetCredential()` method is called here without a message, and it returns a `System.Net.NetworkCredential` object.
3. This is a just a sample, and for testing purposes we print the `Password` property of the network credential we received. This statement uses string interpolation.
4. We call `Console.ReadKey()` with the boolean `true` to indicate that the key should be suppressed from the console.

## The GetCredential() methods

At the top of the `SecureConsole` class are the `GetCredential()` and an overload `GetCredential(message)` which optionally prints the specified message to the user before presenting the "Username" and "Password" fields.

```csharp linenums="30" title="program.cs"
  public static class SecureConsole
  {
    public static NetworkCredential GetCredential()
    {
      return GetCredential(string.Empty); // (1)
    }

    public static NetworkCredential GetCredential(string message)
    {
      if (!string.IsNullOrWhiteSpace(message)) // (2)
      {
        Console.WriteLine(message);
      }
      Console.Write("Username: ");
      var username = Console.ReadLine();

      Console.Write("Password: ");
      var password = SecureConsole.ReadLine(); // (3)

      return new NetworkCredential(username, password);
    }
```

1. In the first overload of the `GetCredential()` method, we call the second overload with an empty message.
2. In the second overload of `GetCredential()`, we print the message to the console if one was provided.
3. Then we collect the plain text username and a `System.Security.SecureString` password before returning the pair in a new `System.Net.NetworkCredential`.

## SecureConsole.ReadLine()

Finally, the `SecureConsole.ReadLine()` method. It's similar to `Console.ReadLine()` in behavior as accepts console input until a carriage return is received. The difference is that the character will not be written to the terminal, it gets stored one character at a time into an encrypted `SecureString`, and an asterisk will be written to the console so the user recognizes that the character has been received.

```csharp linenums="52" title="program.cs"
public static SecureString ReadLine()
    {
      var password = new SecureString();
      ConsoleKeyInfo key;
      while ((key = Console.ReadKey(true)).Key != ConsoleKey.Enter) // (1)
      {
        if (key.Key == ConsoleKey.Backspace && password.Length > 0) // (2)
        {
          Console.Write("\b \b");
          password.RemoveAt(password.Length - 1);
        }
        else if (!char.IsControl(key.KeyChar)) // (3)
        {
          Console.Write("*");
          password.AppendChar(key.KeyChar);
        }
      }
      Console.Write(Environment.NewLine); // (4)
      return password;
    }
  }
}
```

1. This `while` loop uses `Console.ReadKey(true)` to receive a keypress from the console, and as long as it isn't an Enter key, the loop executes.
2. Next we check to see if the key was the `ConsoleKey.Backspace`. If so, we write two `\b` backspace characters to the terminal on either side of a "space" character. This effectively types "backspace - space - backspace" into the console to erase the last asterisk.
3. If the key wasn't a backspace, and the key is also not a control character like __CTRL__ or __HOME__, then an asterisk is written to the console, and we append the character to the SecureString defined on line 54.
4. We're now out of the `while` loop, but the last __Enter__ keypress was suppressed from the console, so we use `Console.Write(Environment.NewLine)` to move the console cursor to the start of the next line before returning the completed `SecureString`.

## Final thoughts

There are probably more secure and complex ways to protect user input in a console app and thwart shoulder-surfing ne'er-do-wells, but this method seemed like a solid, lightweight alternative to showing passwords in plain text and storing them in simple strings. I wonder if there's a way to do it where we don't keep an unprotected `char` in memory? Let me know if there's a simpler, and/or more secure method to accomplish the same thing within the scope of a console application!
