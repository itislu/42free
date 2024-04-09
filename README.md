# 📁 42free 📁

### 42free is a shell script that helps you manage your limited storage on 42 campuses.

**Never run `ncdu` again.**
- You only need to run 42free once for every file or directory you want to free the space of.
  From that point onwards, they will accumulate their space outside of your home directory.

**Easy to use.**
- 42free is designed to be easy to use. You don't have to go to a certain directory or give full paths as arguments.
  You can use it from any directory and you can pass multiple arguments at once. It will detect what you want to do.

**No data loss.**
- You will not lose any data by running 42free, it only moves the data.
  All programs that need the moved directories and files will continue to work normally.

**You are in control.**
- 42free will prompt you for confirmation if it encounters any unusual situation before doing anything.
  It will not overwrite files without asking you.

**Reversable.**
- You can always restore the moved directories and files back to their original location.

**Storage limit aware.**
- 42free will detect if moving more files to sgoinfre would go over the allowed storage limit and will warn you.

---

## Installation

To install 42free, you can use the following command:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/itislu/42free/main/install.sh)
```

This will download the `42free.sh` script into a hidden `.scripts` directory in your home directory.

It will also add an alias `42free` to your shell's RC file (either `.bashrc` or `.zshrc`) so you can use it from any directory.

---

## Usage

```bash
42free file_or_dir
```

- Use 42free by running the `42free` command followed by any amount of files or directories you want to free the space of.

- The arguments can be specified as absolute or relative paths.

- Closing all programs first will help to avoid errors during the move.

> [!TIP]
> **You can pass options anywhere in your command to change the behavior of 42free:**
>
> - Use the `-r` option to move any directories and files back to their original location.
>
> - To get some suggested directories to free, run `42free -s`.
>
> - To see the manual, run `42free -h`.

---

## How it works

42free works by moving files and directories from your home directory to the sgoinfre directory and leaving behind a symbolic link in the original directory.

The allowed space in sgoinfre is usually much higher than in your home directory.

Applications that need the moved files will just follow the symbolic link and access them from sgoinfre.

---

## Confirmed to work for the following 42 campuses:

| Campus | home | sgoinfre |
| --- | --- | --- |
| 🇦🇹 42 Vienna | 5GB | 30GB |

---

## Contributing

- If this script worked for you and your peers, please let me (and others) know by posting in the [Discussions](https://github.com/itislu/42free/discussions) page.
  All confirmed campuses will be added to the [table](https://github.com/itislu/42free/edit/main/README.md#confirmed-to-work-for-the-following-42-campuses) above.

- If you have ideas how 42free could be improved, checkout the [Discussions](https://github.com/itislu/42free/discussions) page and feel free to post there! I will see it and respond.

- If the storage layout on your campus is different, please let me (and others) know by posting in, you guessed it, the [Discussions](https://github.com/itislu/42free/discussions) page.

- If you want to report a bug, please open an issue or create a pull request with a possible fix!
  I'm super grateful for any and all contributions.

---

## 🐬 Fun fact

The English translation for the French word _goinfre_ (/ɡwɛ̃fʁ/ - pronounced 'gwah(n)-fruh') is "glutton" (definition of glutton: an excessively greedy eater).

Knowing that, goinfre might also be a reference to the character _Ford Prefect_ from _The Hitchhiker's Guide to the Galaxy_, who is the friend and savior of _Arthur_.
He is known to be an excessive eater and drinker.
