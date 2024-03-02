# 42free

### 42free is a bash script that helps you manage your limited storage on 42 campuses.

#### Easy to use.
- 42free is designed to be easy to use and flexible, allowing you to specify which directories and files to free the space of.

#### No data loss.
- You will not lose any data by running 42free, it only moves the data.
  All programs that need the moved directories and files will continue to work normally.

#### Run and forget.
- You only need to run it once for every directory or file you want to free.
  From that point onwards, they will accumulate their space outside of your home directory.

#### Reversable.
- You can always restore the moved directories and files back to their original position.

#### Aware of limits.
- 42free will detect if moving more files to sgoinfre would go over the allowed storage limit and will warn you.

---

## How it works

42free works by moving directories or files from your home directory to the sgoinfre directory and leaving behind a symbolic link in the original directory.

This works because the allowed space in sgoinfre is usually much larger than the allowed space in your home directory.

---

## Confirmed to work for the following 42 campuses:

| Campus | home | sgoinfre |
| --- | --- | --- |
| 🇦🇹 42 Vienna | 5GB | 30GB |

---

## Installation

To install 42free, you can use the following command:

- With curl:
  ```bash
  bash <(curl -sSL https://raw.githubusercontent.com/itislu/42free/main/install.sh)
  ```

- With wget:
  ```bash
  bash <(wget -qO- https://raw.githubusercontent.com/itislu/42free/main/install.sh)
  ```

This will download the `42free.sh` script into a hidden `.scripts` directory in your home directory.
It will also add an alias `42free` to your shell's RC file (either `.bashrc` or `.zshrc`) so you can use it from any directory.

---

## Usage

You can use 42free by running the `42free` command followed by any amount of directories or files you want to move.
The arguments can be specified as absolute or relative paths.
42free will automatically detect if the given argument is the source you want to move, or the destination you want to move the source to.

```bash
42free target1 [target2 ...]
```

**You can pass options to change the behavior of 42free:**

- You can use the `-r` option to move any directories and files back to their original location.

- To get some suggested directories to move, run `42free -s`.

- To see the manual, run `42free -h`.

---

## Contributing

- If this script worked for you and your peers, please let me (and others) know by posting in the [Discussions](https://github.com/itislu/42free/discussions) page.
  All confirmed campuses will be added to the [table](https://github.com/itislu/42free/edit/main/README.md#confirmed-to-work-for-the-following-42-campuses) above.

- If you have ideas how 42free could be improved, checkout the [Discussions](https://github.com/itislu/42free/discussions) page and feel free to post there! I will see it and respond.

- If the storage layout on your campus is different, please let me (and others) know by posting in, you guessed it, the [Discussions](https://github.com/itislu/42free/discussions) page.

- If you want to report a bug, please open an issue or create a pull request with a possible fix!
  I'm super grateful for any and all contributions.

---

## Fun fact

The English translation for the French word _goinfre_ is "glutton" (definition of glutton: an excessively greedy eater).

Knowing that, goinfre might also be a reference to the character _Ford Prefect_ from _The Hitchhiker's Guide to the Galaxy_, who is the friend and savior of _Arthur_.
He is known to be an excessive eater and drinker.
