import { List, ActionPanel, Action, showToast, Toast, getPreferenceValues } from "@raycast/api";
import { useExec } from "@raycast/utils";
import { exec } from "child_process";

interface Preferences {
  cliPath: string;
}

interface Bookmark {
  id: string;
  label: string;
}

function parseOutput(stdout: string): Bookmark[] {
  return stdout
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [id, ...rest] = line.split("\t");
      return { id, label: rest.join("\t") || id };
    });
}

export default function Command() {
  const { cliPath } = getPreferenceValues<Preferences>();
  const cli = cliPath || "/usr/local/bin/focusbm";

  const { data, isLoading, error } = useExec(cli, ["list", "--format=fzf"], {
    parseOutput: ({ stdout }) => parseOutput(stdout),
  });

  const bookmarks = data ?? [];

  async function restoreBookmark(id: string) {
    const toast = await showToast({ style: Toast.Style.Animated, title: "Restoring..." });
    exec(`${cli} restore "${id}"`, (err) => {
      if (err) {
        toast.style = Toast.Style.Failure;
        toast.title = "Failed";
        toast.message = err.message;
      } else {
        toast.style = Toast.Style.Success;
        toast.title = `Restored: ${id}`;
      }
    });
  }

  if (error) {
    return <List><List.EmptyView title="Error" description={error.message} /></List>;
  }

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search bookmarks...">
      {bookmarks.map((bm) => (
        <List.Item
          key={bm.id}
          title={bm.id}
          subtitle={bm.label}
          actions={
            <ActionPanel>
              <Action title="Restore" onAction={() => restoreBookmark(bm.id)} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
