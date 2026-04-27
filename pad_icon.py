import sys
from PIL import Image

def pad_image(input_path, output_path, padding_ratio=0.2):
    # Open the original image
    img = Image.open(input_path)
    
    # Calculate the new size of the actual icon
    old_size = img.size
    # Shrink the image so that when padded, it occupies the same old_size
    # So if padding_ratio is 0.2 (20% padding on each side), the new icon size is 1 - 2*0.2 = 0.6 of the original size
    
    # Let's say we want 15% padding on all sides. 
    # That means the icon will be 70% of the total canvas size.
    target_canvas_size = old_size[0] # assuming square
    
    # Let's do a simple resize to 70% of original, then paste into center of transparent canvas.
    new_icon_size = int(target_canvas_size * 0.7)
    
    # Resize the icon using high quality filter
    img_resized = img.resize((new_icon_size, new_icon_size), Image.Resampling.LANCZOS)
    
    # Create a new transparent image for the padded version
    new_img = Image.new("RGBA", old_size, (0, 0, 0, 0))
    
    # Calculate top left position
    offset = ((target_canvas_size - new_icon_size) // 2, (target_canvas_size - new_icon_size) // 2)
    
    # Paste the resized icon onto the center
    new_img.paste(img_resized, offset)
    
    # Save the result
    new_img.save(output_path)
    print(f"Successfully padded image to {output_path}")

if __name__ == "__main__":
    pad_image("assets/images/appicon.png", "assets/images/appicon_padded.png")
