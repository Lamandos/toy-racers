import java.awt.image.BufferedImage;
import java.io.File;
import java.util.ArrayDeque;
import javax.imageio.ImageIO;

/** Extracts the five original car drawings from the user-provided model sheet. */
public final class ProcessCarModelSheet {
    private static final int[][] CAR_BOUNDS = {
        {20, 300, 235, 570},
        {270, 300, 235, 570},
        {510, 300, 225, 570},
        {740, 300, 255, 570},
        {995, 300, 250, 570},
    };
    private static final String[] OUTPUT_NAMES = {
        "red-stripe.png",
        "blue-stripe.png",
        "yellow-sport.png",
        "green-racer.png",
        "orange-truck.png",
    };

    private ProcessCarModelSheet() {}

    public static void main(String[] arguments) throws Exception {
        if (arguments.length != 2) {
            throw new IllegalArgumentException("Usage: ProcessCarModelSheet input.png output-directory");
        }
        BufferedImage sheet = ImageIO.read(new File(arguments[0]));
        File outputDirectory = new File(arguments[1]);
        if (!outputDirectory.isDirectory() && !outputDirectory.mkdirs()) {
            throw new IllegalStateException("Could not create " + outputDirectory);
        }

        for (int index = 0; index < CAR_BOUNDS.length; index++) {
            int[] bounds = CAR_BOUNDS[index];
            BufferedImage crop = sheet.getSubimage(bounds[0], bounds[1], bounds[2], bounds[3]);
            BufferedImage transparent = removeEdgeConnectedBackground(crop);
            BufferedImage fitted = fitToGameCanvas(transparent);
            File output = new File(outputDirectory, OUTPUT_NAMES[index]);
            if (!ImageIO.write(fitted, "png", output)) {
                throw new IllegalStateException("No PNG writer is available for " + output);
            }
        }
    }

    private static BufferedImage removeEdgeConnectedBackground(BufferedImage source) {
        int width = source.getWidth();
        int height = source.getHeight();
        boolean[][] background = new boolean[height][width];
        ArrayDeque<Integer> pending = new ArrayDeque<>();
        for (int x = 0; x < width; x++) {
            enqueueBackground(source, x, 0, background, pending);
            enqueueBackground(source, x, height - 1, background, pending);
        }
        for (int y = 0; y < height; y++) {
            enqueueBackground(source, 0, y, background, pending);
            enqueueBackground(source, width - 1, y, background, pending);
        }
        while (!pending.isEmpty()) {
            int point = pending.removeFirst();
            int x = point % width;
            int y = point / width;
            enqueueBackground(source, x - 1, y, background, pending);
            enqueueBackground(source, x + 1, y, background, pending);
            enqueueBackground(source, x, y - 1, background, pending);
            enqueueBackground(source, x, y + 1, background, pending);
        }

        BufferedImage result = new BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                if (!background[y][x]) result.setRGB(x, y, source.getRGB(x, y));
            }
        }
        return result;
    }

    private static void enqueueBackground(
        BufferedImage image,
        int x,
        int y,
        boolean[][] background,
        ArrayDeque<Integer> pending
    ) {
        if (x < 0 || y < 0 || y >= image.getHeight() || x >= image.getWidth() || background[y][x]) return;
        int color = image.getRGB(x, y);
        int red = color >> 16 & 255;
        int green = color >> 8 & 255;
        int blue = color & 255;
        int maximum = Math.max(red, Math.max(green, blue));
        int minimum = Math.min(red, Math.min(green, blue));
        boolean lightCheckerboard = minimum >= 220 && maximum - minimum <= 12;
        boolean magentaChromaKey = red >= 180 && blue >= 180 && green <= 150 &&
            Math.abs(red - blue) <= 75;
        if (!lightCheckerboard && !magentaChromaKey) return;
        background[y][x] = true;
        pending.addLast(y * image.getWidth() + x);
    }

    private static BufferedImage fitToGameCanvas(BufferedImage source) {
        int minX = source.getWidth();
        int minY = source.getHeight();
        int maxX = -1;
        int maxY = -1;
        for (int y = 0; y < source.getHeight(); y++) {
            for (int x = 0; x < source.getWidth(); x++) {
                if ((source.getRGB(x, y) >>> 24) != 0) {
                    minX = Math.min(minX, x);
                    minY = Math.min(minY, y);
                    maxX = Math.max(maxX, x);
                    maxY = Math.max(maxY, y);
                }
            }
        }
        BufferedImage cropped = source.getSubimage(minX, minY, maxX - minX + 1, maxY - minY + 1);
        double scale = Math.min(58.0 / cropped.getWidth(), 122.0 / cropped.getHeight());
        int width = (int) Math.round(cropped.getWidth() * scale);
        int height = (int) Math.round(cropped.getHeight() * scale);
        BufferedImage result = new BufferedImage(64, 128, BufferedImage.TYPE_INT_ARGB);
        int offsetX = (64 - width) / 2;
        int offsetY = (128 - height) / 2;
        for (int y = 0; y < height; y++) {
            double sourceY = (y + 0.5) * cropped.getHeight() / height - 0.5;
            for (int x = 0; x < width; x++) {
                double sourceX = (x + 0.5) * cropped.getWidth() / width - 0.5;
                result.setRGB(offsetX + x, offsetY + y, bilinearSample(cropped, sourceX, sourceY));
            }
        }
        return result;
    }

    private static int bilinearSample(BufferedImage image, double x, double y) {
        int x0 = Math.max(0, Math.min(image.getWidth() - 1, (int) Math.floor(x)));
        int y0 = Math.max(0, Math.min(image.getHeight() - 1, (int) Math.floor(y)));
        int x1 = Math.min(image.getWidth() - 1, x0 + 1);
        int y1 = Math.min(image.getHeight() - 1, y0 + 1);
        double fractionX = x - Math.floor(x);
        double fractionY = y - Math.floor(y);
        int[] colors = {
            image.getRGB(x0, y0),
            image.getRGB(x1, y0),
            image.getRGB(x0, y1),
            image.getRGB(x1, y1),
        };
        double[] weights = {
            (1.0 - fractionX) * (1.0 - fractionY),
            fractionX * (1.0 - fractionY),
            (1.0 - fractionX) * fractionY,
            fractionX * fractionY,
        };
        double alpha = 0.0;
        double red = 0.0;
        double green = 0.0;
        double blue = 0.0;
        for (int index = 0; index < colors.length; index++) {
            double weightedAlpha = (colors[index] >>> 24) / 255.0 * weights[index];
            alpha += weightedAlpha;
            red += (colors[index] >> 16 & 255) * weightedAlpha;
            green += (colors[index] >> 8 & 255) * weightedAlpha;
            blue += (colors[index] & 255) * weightedAlpha;
        }
        if (alpha <= 0.0) return 0;
        int outputAlpha = clampToByte(alpha * 255.0);
        int outputRed = clampToByte(red / alpha);
        int outputGreen = clampToByte(green / alpha);
        int outputBlue = clampToByte(blue / alpha);
        return outputAlpha << 24 | outputRed << 16 | outputGreen << 8 | outputBlue;
    }

    private static int clampToByte(double value) {
        return Math.max(0, Math.min(255, (int) Math.round(value)));
    }
}
