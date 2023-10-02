---
draft: true
date:
  created: 2023-10-02
authors:
 - joshooaj
categories:
  - PowerShell
---

# Generate markdown tables from PowerShell

I had a need to generate a markdown table dynamically from PowerShell, so I wrote a flexible function which uses the
properties on the incoming objects to define the column names, supports the definition of maximum column widths, and
outputs either pretty-printed markdown with padded values and aligned columns, or "compressed" markdown without the
unnecessary padding included.

<!-- more -->

As an alternative when working an mkdocs project, you can use the [table-reader plugin](https://pypi.org/project/mkdocs-table-reader-plugin/)
to reference a CSV file in markdown. I tested this out successfully and it's a really handy tool, but in the end I wanted
a method of generating a markdown table that did not depend on the use of mkdocs or python.

[Download :material-download:](ConvertTo-MarkdownTable.ps1){ .md-button .md-button--primary }

```powershell linenums="1"
--8<-- "blog/posts/ConvertTo-MarkdownTable/ConvertTo-MarkdownTable.ps1"
```
