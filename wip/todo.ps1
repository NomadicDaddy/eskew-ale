<#
	.DESCRIPTION
	
		Manages a todo list.

		todo					Print todos
		todo help				Lists the available commands
		todo add Go shopping	Create a new todo item
		todo ls					Print all pending todo items
		todo ls @tag			Print todo items containing "@tag"
		todo ls ~@tag			Print todo items not containing "@tag"
		todo ls --all			Print completed and pending todo items
		todo ls --done			Print completed todo items
		todo check 1			Mark #1 as completed
		todo mv 1 42			Change the id of given todo
		todo undo 1				Revert #1 to pending
		todo rm 1				Remove #1 item
		todo clear				Destroy all todo items
	
	.PARAMETER file
	.PARAMETER pattern
#>
