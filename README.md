<div align="center">

  # 📁&nbsp; 42free &nbsp;📁

  ### 42free is a shell script that helps you manage your limited storage on 42 campuses.

  #### ⚙️ 42free supports Linux and macOS.

  <br>

  ### 🚀 Quick Install

  ```bash
  bash <(curl -sSL https://raw.githubusercontent.com/itislu/42free/main/install.sh)
  ```

  <br>

  <a href="https://github.com/itislu/42free/releases">
    <img
      alt="GitHub Downloads (all assets, all releases)"
      src="https://img.shields.io/github/downloads/itislu/42free/total?style=for-the-badge&logo=GNOME%20Terminal&logoColor=%23241f31&logoSize=auto&label=downloads&labelColor=%23f8d765&color=%23241f31"
    >
  </a>
</div>

<br>

---

<br>

## 🧭 Contents

- [📌 Overview](#-overview)

- [🛠️ Installation](#%EF%B8%8F-installation)

- [👩‍💻 Usage](#-usage)

- [💡 How it works](#-how-it-works)

- [🌍 Confirmed to work for the following campuses](#-confirmed-to-work-for-the-following-campuses)

- [🤝 Contributing](#-contributing)

- [🐬 Fun fact](#-fun-fact)

<br>

---

<br>

## 📌 Overview

**No data loss.**
- You will not lose any data by running 42free, it only moves the data to sgoinfre.<br>
  All programs that need the moved directories and files will continue to work normally.

**No worries about storage anymore.**
- You only need to run 42free once for every file or directory you want to free the space of.<br>
  From that point onwards, they will accumulate their space outside of your home directory.

**Reversable.**
- You can always restore the moved directories and files back to their original location.

**Storage limit aware.**
- 42free will detect if moving more files to sgoinfre would go over the allowed storage limit and will warn you.

**Easy to use.**
- 42free is designed to be easy to use. You don't have to go to a certain directory or give full paths as arguments.
  You can use it from any directory and you can pass multiple arguments at once, or none at all. It will detect what you want to do.

**You are in control.**
- 42free will prompt you for confirmation if it encounters any unusual situation before doing anything.<br>
  It will not overwrite files without asking you.

<br>

---

<br>

## 🛠️ Installation

To install 42free, you can use one of the following commands:

- With curl:
  ```bash
  bash <(curl -sSL https://raw.githubusercontent.com/itislu/42free/main/install.sh)
  ```

- With wget:
  ```bash
  bash <(wget -qO- https://raw.githubusercontent.com/itislu/42free/main/install.sh)
  ```

This will download the `42free.sh` script into a hidden `.scripts` directory in your home directory.

It will also add an alias `42free` to your shells' config files (`.bashrc`, `.zshrc` and `config.fish`) so you can use it from any directory.

<br>

---

<br>

## 👩‍💻 Usage

```bash
42free [TARGET]... [OPTION]...
```

- Use 42free by running the `42free` command in the terminal.

- 42free will make suggestions what to free if you run it without arguments.

<br>

- **Optional:** You can specify any amount of files or directories you want to free the space of.
  - The arguments can be given as absolute or relative paths.

  - Example: `42free /path/to/large/directory largeFileInCurDir`

<br>

> [!TIP]
> - **Closing all programs first will help to avoid errors during the move.**
>
> - You can pass options anywhere in your command to change the behavior of 42free.
>   - Example: `42free -r /path/to/large/directory/in/sgoinfre symLinkInCurDir`
>
> | Option        | Description                                                                                    |
> | ------------- | ---------------------------------------------------------------------------------------------- |
> | `--restore`   | Use the `-r` option to move directories and files back to their original location.             |
> | `--sgoinfre`  | To change the path that 42free considers as your personal sgoinfre directory, run `42free -s`. |
> | `--max-size`  | To change the warning sizes for the home and sgoinfre directories, run `42free -m`.            |
> | `--update`    | To update to the latest version, run `42free -u`.                                              |
> | `--version`   | To see the version information, run `42free -v`.                                               |
> | `--uninstall` | To uninstall 42free, run `42free --uninstall`.                                                 |
> | `--help`      | To see the manual, run `42free --help` (or `42free -h` for the short version).                 |

<br>

---

<br>

## 💡 How it works

42free works by moving files and directories from your home directory to the sgoinfre directory and leaving behind a symbolic link in the original directory.

The allowed space in sgoinfre is usually much higher than in your home directory.

Applications that need the moved files will just follow the symbolic link and access them from sgoinfre.

<br>

---

<br>

## 🌍 Confirmed to work for the following campuses

| Campus         | home | sgoinfre | OS    |
| -------------- | ---- | -------- | ----- |
| 🇦🇹 42 Vienna   | 5GB  | 30GB     | Linux |
| 🇩🇪 42 Berlin   | 5GB  | 30GB     | Linux |
| 🇧🇪 19 Brussels | 5GB  | 15GB     | macOS |
| 🇹🇭 42 Bangkok  | 15GB | 15GB     | Linux |

Confirm **your** campus [here](https://github.com/itislu/42free/discussions/11).

<br>

---

<br>

## 🤝 Contributing

- If this script worked for you and your peers, please let me (and others) know by posting or reacting to already existing posts in the [💬 Discussions](https://github.com/itislu/42free/discussions) page.

- If the storage layout on your campus is different, you can post in [here](https://github.com/itislu/42free/discussions/5). A template is already prepared for you 😊
  <br>
  All confirmed campuses will be added to the 🌍 table above.

- If you have ideas how 42free could be improved, checkout the [💡 Feedback & Ideas](https://github.com/itislu/42free/discussions/categories/feedback-ideas) section in the Discussions page and feel free to post there!
  <br>
  I will see it and respond.

- If you want to report a bug, please open an Issue or create a Pull Request with a possible fix!
  <br>
  I'm super grateful for any and all contributions.
  <br>
  If your changes get merged, you will also be mentioned as a contributor in the [release notes](https://github.com/itislu/42free/releases)!

<br>

### 🏆 BIG thank you to all contributors!

| Contributor                                    | Contribution                                                        |
| ---------------------------------------------- | ------------------------------------------------------------------- |
| [@JonatV](https://github.com/JonatV)           | Thank you for helping with macOS support!                           |
| [@Anantiz](https://github.com/Anantiz)         | Thank you for stress testing!                                       |
| [@alexandregv](https://github.com/alexandregv) | Thank you for showing me how 42 Paris does it!                      |
| [@loyc12](https://github.com/loyc12)           | Thank you for helping to increase compatibility with more campuses! |
| [@kcp2p](https://github.com/kcp2p)             | Thank you for reporting the storage layout at 42 Bangkok!           |

Also thank you to all my peers at 42 Vienna for the constant feedback! ❤️<br>
[@LeaYeh](https://github.com/LeaYeh), [@ismayilguliyev28](https://github.com/ismayilguliyev28), [@Rperkmann](https://github.com/Rperkmann), [@michaela811](https://github.com/michaela811), [@grignetta](https://github.com/grignetta), [@yenthing](https://github.com/yenthing), [@leske42](https://github.com/leske42), [@ARWChair](https://github.com/ARWChair)<br>
<details>
  <summary>And thank you to <a href="https://github.com/Zekao">@Zekao</a> for sparking the idea in the first place.</summary>
  <img src="https://github.com/user-attachments/assets/4ed0feda-4744-43f9-af2a-5c131d81d8a4">
</details>

<br>

---

<br>

## 🐬 Fun fact

The English translation for the French word _goinfre_ (/ɡwɛ̃fʁ/ - pronounced 'gwah(n)-fruh') is "glutton" (definition of glutton: an excessively greedy eater).

Knowing that, goinfre might also be a reference to the character _Ford Prefect_ from _The Hitchhiker's Guide to the Galaxy_, who is the friend and savior of _Arthur_.
<br>
He is known to be an excessive eater and drinker.

<br>
