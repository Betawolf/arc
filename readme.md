#Arc

Arc is designed for saving and annotating things. Specifically, interesting texts found online.

Intended functionality:

```{bash}
arc add <url>
```
should cause the system to 
	1) download the specified file, 
	2) detect the mimetype
	3) extract the text into a .txt version for searc purposes
	4) extract or guess at the title
	5) open $EDITOR with the title pre-loaded for editing, and ready to accept annotation
	6) save the article under the specified title id, storing a log in a master file

```{bash}
arc search <txt>
```
should cause the system to do a full-text search for matches and present the resulting ids


```{bash}
arc open <id>
```
should cause the system to open the specified text in the appropriate program


```{bash}
arc view <id>
```
should cause the system to open the annotations for the  specified text in the browser


```{bash}
arc sync 
```
should cause the system to sync its contents with a specified remote repository
