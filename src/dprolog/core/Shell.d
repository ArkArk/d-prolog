module dprolog.core.Shell;

import dprolog.util.Either;
import dprolog.util.Message;

import std.stdio : StdioException;
import std.conv;
import std.string;
import std.process;
import std.file : chdir, FileException;

Either!(Message, string[]) executeLs() {
  try {
    auto result = executeShell("ls");
    if (result.status == 0) {
      return result.output.chomp.splitLines.Right!(Message, string[]);
    } else {
      return ErrorMessage(result.output.chomp).Left!(Message, string[]);
    }
  } catch (ProcessException e) {
    return ErrorMessage(e.msg).Left!(Message, string[]);
  } catch (StdioException e) {
    return ErrorMessage(e.msg).Left!(Message, string[]);
  }
}

Either!(Message, string[]) executeLsWithPath(string path) {
  try {
    auto result = executeShell("ls " ~ path);
    if (result.status == 0) {
      return result.output.chomp.splitLines.Right!(Message, string[]);
    } else {
      return ErrorMessage(result.output.chomp).Left!(Message, string[]);
    }
  } catch (ProcessException e) {
    return ErrorMessage(e.msg).Left!(Message, string[]);
  } catch (StdioException e) {
    return ErrorMessage(e.msg).Left!(Message, string[]);
  }
}

Either!(Message, string[]) executeCdWithPath(string path) {
  try {
    auto echoResult = executeShell("echo " ~ path);
    if (echoResult.status == 0) {
      echoResult.output.chomp.chdir;
    } else {
      path.chdir;
    }
    return [].Right!(Message, string[]);
  } catch (ProcessException e) {
    return ErrorMessage(e.msg).Left!(Message, string[]);
  } catch (StdioException e) {
    return ErrorMessage(e.msg).Left!(Message, string[]);
  } catch (FileException e) {
    return ErrorMessage(e.msg).Left!(Message, string[]);
  }
}
