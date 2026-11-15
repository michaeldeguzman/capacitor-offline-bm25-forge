using System.Text;

// Writes one line per UTF-16 code unit (0000 to FFFF):
//   <hex unit> <IsLetterOrDigit> <IsWhiteSpace> <IsDigit> <hex first unit of ToLowerInvariant>
// The first line is a comment with the .NET version. Usage: dotnet run -- <output path>
var sb = new StringBuilder();
sb.Append("# ").Append(System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription).Append('\n');
for (int i = 0; i <= 0xFFFF; i++)
{
    char c = (char)i;
    string lower = c.ToString().ToLowerInvariant();
    sb.Append($"{i:X4} {(char.IsLetterOrDigit(c) ? 1 : 0)} {(char.IsWhiteSpace(c) ? 1 : 0)} {(char.IsDigit(c) ? 1 : 0)} {(int)lower[0]:X4}\n");
}
File.WriteAllText(args[0], sb.ToString(), new UTF8Encoding(false));
