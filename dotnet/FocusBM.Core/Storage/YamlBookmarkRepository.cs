namespace FocusBM.Core;

public interface IBookmarkRepository
{
    Task<BookmarkStore> LoadAsync(CancellationToken cancellationToken = default);
    Task SaveAsync(BookmarkStore store, CancellationToken cancellationToken = default);
}

public sealed class YamlBookmarkRepository : IBookmarkRepository
{
    private readonly string _path;
    private readonly BookmarkYamlSerializer _serializer;

    public YamlBookmarkRepository(string path, BookmarkYamlSerializer? serializer = null)
    {
        _path = path;
        _serializer = serializer ?? new BookmarkYamlSerializer();
    }

    public async Task<BookmarkStore> LoadAsync(CancellationToken cancellationToken = default)
    {
        if (!File.Exists(_path)) return new BookmarkStore(new AppSettings(), Array.Empty<Bookmark>());
        var text = await File.ReadAllTextAsync(_path, cancellationToken).ConfigureAwait(false);
        return _serializer.Deserialize(text);
    }

    public async Task SaveAsync(BookmarkStore store, CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(_path))!);
        var text = _serializer.Serialize(store);
        var tmp = _path + ".tmp";
        var bak = _path + ".bak";
        var lockPath = _path + ".lock";
        await using var lockStream = new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        await File.WriteAllTextAsync(tmp, text, cancellationToken).ConfigureAwait(false);
        if (File.Exists(_path)) File.Copy(_path, bak, overwrite: true);
        File.Move(tmp, _path, overwrite: true);
    }
}
