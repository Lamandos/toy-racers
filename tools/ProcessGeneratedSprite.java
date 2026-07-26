import java.awt.image.BufferedImage;
import java.io.File;
import javax.imageio.ImageIO;

/** Removes a green-screen background and fits one generated sprite into a transparent canvas. */
public final class ProcessGeneratedSprite {
    private ProcessGeneratedSprite() {}

    public static void main(String[] arguments) throws Exception {
        if (arguments.length != 2) {
            throw new IllegalArgumentException("Usage: ProcessGeneratedSprite input.png output.png");
        }
        BufferedImage source = ImageIO.read(new File(arguments[0]));
        BufferedImage keyed = new BufferedImage(
            source.getWidth(),
            source.getHeight(),
            BufferedImage.TYPE_INT_ARGB
        );
        int minX = source.getWidth();
        int minY = source.getHeight();
        int maxX = -1;
        int maxY = -1;
        for (int y = 0; y < source.getHeight(); y++) {
            for (int x = 0; x < source.getWidth(); x++) {
                int color = source.getRGB(x, y);
                int red = color >> 16 & 255;
                int green = color >> 8 & 255;
                int blue = color & 255;
                int dominance = green - Math.max(red, blue);
                int alpha = Math.max(0, Math.min(255, 255 - (dominance - 18) * 5));
                int despilledGreen = Math.min(green, Math.max(red, blue) + 20);
                if (alpha > 8) {
                    minX = Math.min(minX, x);
                    minY = Math.min(minY, y);
                    maxX = Math.max(maxX, x);
                    maxY = Math.max(maxY, y);
                }
                keyed.setRGB(
                    x,
                    y,
                    alpha << 24 | red << 16 | despilledGreen << 8 | blue
                );
            }
        }
        if (maxX < minX || maxY < minY) {
            throw new IllegalStateException("No opaque sprite pixels found");
        }

        BufferedImage cropped = keyed.getSubimage(minX, minY, maxX - minX + 1, maxY - minY + 1);
        BufferedImage result = new BufferedImage(64, 128, BufferedImage.TYPE_INT_ARGB);
        double scale = Math.min(56.0 / cropped.getWidth(), 120.0 / cropped.getHeight());
        int width = (int) Math.round(cropped.getWidth() * scale);
        int height = (int) Math.round(cropped.getHeight() * scale);
        int offsetX = (64 - width) / 2;
        int offsetY = (128 - height) / 2;
        for (int y = 0; y < height; y++) {
            int sourceY = Math.min(cropped.getHeight() - 1, y * cropped.getHeight() / height);
            for (int x = 0; x < width; x++) {
                int sourceX = Math.min(cropped.getWidth() - 1, x * cropped.getWidth() / width);
                result.setRGB(offsetX + x, offsetY + y, cropped.getRGB(sourceX, sourceY));
            }
        }
        ImageIO.write(result, "png", new File(arguments[1]));
    }
}
