// Puts a code block of the guide into the learner's file, at the place the
// step names, so nobody has to copy and paste it.
//
// A block takes part when the manual has a marker on the line above it.
//
//   <!-- codelab-insert file="shared/src/.../FhirEngineSetup.kt" replace="// 4 Imports for the FHIR Engine" -->
//
// file     The file the code goes into, counted from the codelabs folder.
// after    The code goes on a new line under the line with this text.
// replace  The code takes the place of the line with this text.
// then     Used with replace. The next line is removed too when it starts
//          with this text.
// through  Used with replace. Every line down to the one with this text is
//          removed too.
//
// The guide is the Markdown preview that ships with the editor, and a page
// inside it has no way to call an extension. It can open a link to a file
// though. So each block gets a small signal file, the Insert button is a
// link to it, and this extension acts when the editor opens that file. The
// tab of the signal file is closed again at once.

const vscode = require('vscode');
const fs = require('fs');
const os = require('os');
const path = require('path');

const MARKER = /^\s*<!--\s*codelab-insert\s+(.*?)\s*-->\s*$/;
const SIGNAL_DIR = path.join(os.homedir(), '.codelab', 'insert');
const ATTRIBUTE = 'data-codelab-insert';
// A link in the guide is read from the folder the guide is in.
const GUIDE_DIR = path.dirname(process.env.CODELAB_GUIDE || '/opt/codelab/guide/course-manual.md');

// The blocks of the guide as it was last drawn, by number.
let blocks = [];

function parseMarker(text) {
  const match = MARKER.exec(text);
  if (!match) return undefined;
  const spec = {};
  for (const pair of match[1].matchAll(/([a-z]+)="([^"]*)"/g)) {
    spec[pair[1]] = pair[2];
  }
  if (!spec.file || (!spec.after && !spec.replace)) return undefined;
  return spec;
}

function signalFile(number) {
  return path.join(SIGNAL_DIR, 'block-' + number + '.txt');
}

// Runs each time the preview draws a Markdown file. It notes every marked
// block and writes on it the link its Insert button needs.
function extendMarkdownIt(md) {
  md.core.ruler.push('codelab_insert', (state) => {
    const found = [];
    for (let index = 0; index + 1 < state.tokens.length; index += 1) {
      const token = state.tokens[index];
      const next = state.tokens[index + 1];
      if (token.type !== 'html_block' || next.type !== 'fence') continue;
      const spec = parseMarker(token.content);
      if (!spec) continue;
      const number = found.length;
      found.push({ spec, code: next.content });
      try {
        fs.mkdirSync(SIGNAL_DIR, { recursive: true });
        fs.writeFileSync(signalFile(number), 'The code is being put into your file.\n');
      } catch (ignored) {
        continue;
      }
      next.attrSet(ATTRIBUTE, path.relative(GUIDE_DIR, signalFile(number)));
    }
    if (found.length > 0) blocks = found;
  });
  return md;
}

function trimmedLines(text) {
  return text.replace(/\n+$/, '').split('\n').map((line) => line.trim());
}

// The line where the block already sits in the file, or -1.
function findBlock(fileLines, blockLines) {
  for (let start = 0; start + blockLines.length <= fileLines.length; start += 1) {
    let same = true;
    for (let offset = 0; offset < blockLines.length; offset += 1) {
      if (fileLines[start + offset] !== blockLines[offset]) {
        same = false;
        break;
      }
    }
    if (same) return start;
  }
  return -1;
}

async function showFile(file) {
  const uri = vscode.Uri.file(file);
  let column = vscode.ViewColumn.One;
  for (const tab of vscode.window.tabGroups.all.flatMap((group) => group.tabs)) {
    if (tab.input instanceof vscode.TabInputText && tab.input.uri.fsPath === uri.fsPath) {
      column = tab.group.viewColumn;
      break;
    }
  }
  return vscode.window.showTextDocument(uri, { viewColumn: column, preview: false });
}

function select(editor, firstLine, lastLine) {
  const range = new vscode.Range(firstLine, 0, lastLine, editor.document.lineAt(lastLine).text.length);
  editor.selection = new vscode.Selection(range.start, range.end);
  editor.revealRange(range, vscode.TextEditorRevealType.InCenterIfOutsideViewport);
}

async function insertBlock(number) {
  const block = blocks[number];
  if (!block) {
    vscode.window.showWarningMessage('The guide has to be drawn again first. Click Guide at the bottom of the Editor, then try Insert again.');
    return;
  }
  const { spec, code } = block;
  const file = path.join(process.env.CODELAB_DIR || '', spec.file);
  const name = path.basename(file);
  if (!fs.existsSync(file)) {
    vscode.window.showWarningMessage('The file ' + spec.file + ' is not there. Use Copy and paste the code by hand.');
    return;
  }

  const editor = await showFile(file);
  const document = editor.document;
  const fileLines = document.getText().split(/\r?\n/).map((line) => line.trim());
  const blockLines = trimmedLines(code);

  const already = findBlock(fileLines, blockLines);
  if (already !== -1) {
    select(editor, already, already + blockLines.length - 1);
    vscode.window.showInformationMessage('This code is already in ' + name + '. It is the part now selected.');
    return;
  }

  const anchor = spec.after || spec.replace;
  const at = fileLines.indexOf(anchor);
  if (at === -1) {
    // The block may be in the file with a later step's change inside it. Its
    // first line is then still there.
    const opening = fileLines.indexOf(blockLines.find((line) => line !== ''));
    if (opening !== -1) {
      select(editor, opening, opening);
      vscode.window.showInformationMessage('This code looks to be in ' + name + ' already. It starts at the line now selected.');
      return;
    }
    vscode.window.showWarningMessage(
      'Insert could not find the line "' + anchor + '" in ' + name + '. ' +
        'An earlier step may be missing, or the line was changed. Use Copy and paste the code by hand.',
    );
    return;
  }

  // The last line the new code takes the place of.
  let last = at;
  if (spec.replace && spec.then && at + 1 < fileLines.length && fileLines[at + 1].startsWith(spec.then)) last = at + 1;
  if (spec.replace && spec.through) {
    last = fileLines.indexOf(spec.through, at + 1);
    if (last === -1) {
      vscode.window.showWarningMessage(
        'Insert could not find the line "' + spec.through + '" in ' + name + ', which ends the part this code replaces. ' +
          'Use Copy and paste the code by hand.',
      );
      return;
    }
  }

  // The new lines take the indent of the line they go next to.
  const indent = /^\s*/.exec(document.lineAt(at).text)[0];
  const body = code
    .replace(/\n+$/, '')
    .split('\n')
    .map((line) => (line.trim() === '' ? '' : indent + line))
    .join('\n');

  let firstLine;
  const done = await editor.edit((edit) => {
    if (spec.after) {
      firstLine = at + 1;
      edit.insert(document.lineAt(at).range.end, '\n' + body);
    } else {
      firstLine = at;
      edit.replace(new vscode.Range(document.lineAt(at).range.start, document.lineAt(last).range.end), body);
    }
  });
  if (!done) {
    vscode.window.showWarningMessage('The code could not be put into ' + name + '. Use Copy and paste the code by hand.');
    return;
  }
  select(editor, firstLine, firstLine + blockLines.length - 1);
  vscode.window.showInformationMessage('The code is in ' + name + ', and it is selected so you can see it. Press Ctrl+S to save and build.');
}

function signalNumber(tab) {
  if (!(tab.input instanceof vscode.TabInputText)) return undefined;
  const file = tab.input.uri.fsPath;
  if (path.dirname(file) !== SIGNAL_DIR) return undefined;
  const match = /^block-(\d+)\.txt$/.exec(path.basename(file));
  return match ? Number(match[1]) : undefined;
}

function register(context) {
  context.subscriptions.push(
    vscode.window.tabGroups.onDidChangeTabs(async (event) => {
      for (const tab of event.opened) {
        const number = signalNumber(tab);
        if (number === undefined) continue;
        try {
          await vscode.window.tabGroups.close(tab, true);
        } catch (ignored) {
          // The tab is gone already.
        }
        await insertBlock(number);
      }
    }),
  );
  // A signal tab left by a reload in the middle of a click is only clutter.
  const stale = vscode.window.tabGroups.all.flatMap((group) => group.tabs).filter((tab) => signalNumber(tab) !== undefined);
  if (stale.length > 0) vscode.window.tabGroups.close(stale, true);
}

module.exports = { register, extendMarkdownIt, ATTRIBUTE };
