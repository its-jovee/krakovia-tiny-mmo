@tool
extends EditorScript

## Script to run recipe/item validation from Godot Editor
## Run via: File > Run Script


func _run() -> void:
	print("\n" + "=".repeat(60))
	print("RECIPE & ITEM VALIDATION")
	print("=".repeat(60) + "\n")
	
	var validator = RecipeItemValidator.new()
	validator.validate_all()
	
	# Save report
	var report_path = "res://VALIDATION_REPORT.md"
	validator.save_report(report_path)
	
	print("\n" + "=".repeat(60))
	print("Validation complete! Report saved to:")
	print(report_path)
	print("=".repeat(60) + "\n")
	
	# Print summary to console
	print("\nQUICK SUMMARY:")
	print("- Total Recipes: %d" % validator.total_recipes)
	print("- Total Items: %d" % validator.total_items)
	print("- Total Issues: %d" % validator.total_issues)
	print("")
	print("  - Recipes with No Inputs: %d" % validator.recipes_with_no_inputs.size())
	print("  - Items Without Recipes: %d" % validator.items_without_recipes.size())
	print("  - Broken Recipe References: %d" % validator.broken_recipe_references.size())
	print("  - Duplicate Recipes: %d" % validator.duplicate_recipes.size())
	print("  - Unused Crafted Items: %d" % validator.unused_crafted_items.size())
	print("  - Orphaned Outputs: %d" % validator.orphaned_outputs.size())

