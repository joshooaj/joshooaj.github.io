---
title: Securely Reading Passwords from the Console
summary: How to prompt users for sensitive information like passwords without displaying the characters.
date: 2022-01-04
authors:
    - Josh Hendricks
tags:
    - C#
---

# Securely Reading Passwords from the Console

If you've ever written a console application which requires the user to type sensitive information like a password or a token, you might have wrestled with concerns of exposing the password in plain text within the console window.

Here's an example of how you could securely capture text input from the user without exposing it to shoulder-surfing ne'er-do-wells. Continue reading after the code to explore the example in detail.

![Demonstration of the console application showing the password obscured with asterisks.](/assets/images/SecureConsoleDemo.gif)

```csharp
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
        Console.WriteLine($"You entered '{nc.Password}' for a password.");
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
