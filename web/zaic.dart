import 'dart:html';
import 'dart:async';
import 'dart:math';

Zaic zaic;

void main() {
  
  zaic = new Zaic(
      '', // add a destination image here
      [], // add a list of src images
      querySelector("#canvas") as CanvasElement,
      cellSize: 8,
      maxWidth: 1200
  );
  
  
  zaic.onReady.then((_) {
    // go!
    zaic.displayColorMatches();
  });
}


class Zaic {
  String dest;
  ImageElement destImage;
  List<ImageFingerPrint> destFingerPrints = [];
  
  List<String> src;
  List<ImageElement> srcImages = [];
  List<ImageFingerPrint> srcFingerPrints = [];
  
  int maxWidth;
  int cellSize;
  int width;
  int height;
  int gridWidth;
  int gridHeight;
  
  CanvasElement canvas;
  CanvasRenderingContext2D context;
  
  Completer _completer = new Completer();
  
  Future onReady;
  
  
  Zaic(String this.dest, List<String> this.src, CanvasElement this.canvas, {this.maxWidth: 800, this.cellSize: 10}) {
    context = canvas.getContext('2d');
    
    loadImages();
  }
  
  void loadImages() {
    destImage = new ImageElement();
    destImage.crossOrigin = "anonymous";
    destImage.src = dest;
    destImage.onLoad.first.then((Event e) {
      updateCanvasDimensions();
      display();
      var futures = []; 
      for(var path in src) {
        var image = new ImageElement(src: path);
        srcImages.add(image);
        futures.add(image.onLoad.first);
      }
      Future.wait(futures).then((_) {
        analyzeImages();
        _completer.complete();
      });
    });
    onReady = _completer.future;
  }
  
  void analyzeImages() {
    for(var x = 0; x < width; x += cellSize) {
      for(var y = 0; y < height; y += cellSize) {
        var data = context.getImageData(x, y, cellSize, cellSize);
        destFingerPrints.add(new ImageFingerPrint(data, cellSize));
      }
    }
    
    for(var image in srcImages) {
      srcFingerPrints.add(new ImageFingerPrint.fromImageElement(image, cellSize));
    }
  }
  
  void updateCanvasDimensions() {
    if(destImage.width < maxWidth) {
      width = destImage.width - (destImage.width % cellSize);
    } else {
      width = maxWidth - (maxWidth % cellSize);
    }
    var _height = ((width / destImage.width) * destImage.height).toInt();
    height = _height - (_height % cellSize);
    
    gridWidth = width ~/ cellSize;
    gridHeight = height ~/ cellSize;
    
    canvas = (querySelector("#canvas") as CanvasElement)
        ..width = width
        ..height = height;
  }
  
  void display() {
    context.drawImageScaled(destImage, 0, 0, canvas.width, canvas.height);
  }
  
  void displayColorMatches() {
    for(var i = 0; i < destFingerPrints.length; i++) {
      var imageIdx = findColorMatchImage(destFingerPrints[i]),
          x = (i ~/ gridHeight) * cellSize, 
          y = (i % gridHeight) * cellSize,
          vector = destFingerPrints[i].average.subtract(srcFingerPrints[imageIdx].average);
      
      
//      context.drawImageScaled(image, x, y, cellSize, cellSize);
//      print(srcFingerPrints[imageIdx].data);
      context.putImageData(srcFingerPrints[imageIdx].colorize(vector), x, y, 0, 0, cellSize, cellSize);
//      context.fillStyle = destFingerPrints[i].average.getRGBA();
//      context.fillRect(x, y, cellSize, cellSize);
    }
  }
  
  int findColorMatchImage(ImageFingerPrint fingerPrint) {
    var bestIdx = 0,
        bestDistance = fingerPrint.hammingDistance(srcFingerPrints[0]);
//        bestDistance = fingerPrint.colorDistance(srcFingerPrints[0]);
    for(var i = 1; i < srcFingerPrints.length; i++) {
      var srcFingerPrint = srcFingerPrints[i],
          distance = fingerPrint.hammingDistance(srcFingerPrint);
//          distance = fingerPrint.colorDistance(srcFingerPrint);
      if(distance < bestDistance) {
        bestDistance = distance;
        bestIdx = i;
      }
    }
    return bestIdx;
  }
}

class Color {
  int r;
  int g;
  int b;
  int a;
  
  Color(this.r, this.g, this.b, {this.a: 1});
  
  double distance(Color other) {
    return sqrt(pow(r-other.r, 2) + pow(g-other.g, 2) + pow(b-other.b, 2));
  }
  
  Color subtract(other) {
    return new Color(r - other.r, g - other.g, b - other.b);
  }
  
  String getHex() {
    var _r = ('00' + r.toRadixString(16)),
        _g = ('00' + g.toRadixString(16)),
        _b = ('00' + b.toRadixString(16));
    
    _r = _r.substring(_r.length-2);
    _g = _g.substring(_g.length-2);
    _b = _b.substring(_b.length-2);

    
    return '#${_r.substring(_r.length-2)}${_g}${_b}';
  }
  
  String getRGBA() {
    return 'rgba($r, $g, $b, .2)';
  }
  
  static Color getAverageColor(ImageData data) {
    var r = 0,
        g = 0,
        b = 0,
        size = data.data.length / 4;
    
    for(var i = 0; i < data.data.length; i += 4) {
      r += data.data[i];
      g += data.data[i+1];
      b += data.data[i+2];
    }
    
    r ~/= size;
    g ~/= size;
    b ~/= size;
    
    return new Color(r, g, b);
  }
}

class ImageFingerPrint {
  ImageData data;
  int size;
  Color average;
  List<bool> bitmap = [];
  
  ImageFingerPrint(this.data, this.size) {
    average = Color.getAverageColor(data);
    generateBitmap();
  }
  
  ImageFingerPrint.fromImageElement(ImageElement image, this.size) {
    var canvas = new CanvasElement(width: size, height: size),
        context = canvas.getContext('2d');
    
    context.drawImageScaled(image, 0, 0, size, size);
    data = context.getImageData(0, 0, size, size);
    average = Color.getAverageColor(data);
    generateBitmap();
  }
  
  void generateBitmap() {
    var canvas = new CanvasElement(width: 8, height: 8),
        context = canvas.getContext('2d');
    
    context.putImageData(data, 0, 0, 0, 0, 8, 8);
    
    var smallData = context.getImageData(0, 0, 8, 8),
        avgMap = <int, int>{},
        avgTotal = 0,
        avg = 0;
        
    for(var i = 0; i < smallData.data.length; i += 4) {
      avgMap[i~/4] = (smallData.data[i] + smallData.data[i+1] + smallData.data[i+2]) ~/ 3;
      avgTotal += avgMap[i~/4];
    }
    avg = avgTotal ~/ avgMap.length;
    
    for(var j = 0; j < avgMap.length; j++) {
      bitmap.add(avgMap[j] > avg);
    }
  }
  
  double colorDistance(ImageFingerPrint other) {
    return average.distance(other.average);
  }
  
  int hammingDistance(ImageFingerPrint other) {
    var distance = 0;
    
    for(var i = 0; i < bitmap.length; i++) {
      if(bitmap[i] != other.bitmap[i]) {
        distance += 1;
      }
    }
    return distance;
  }
  
  ImageData colorize(Color vector) {
    var tmpCanvas = new CanvasElement(width: size, height: size),
        copyData = tmpCanvas.getContext('2d').getImageData(0, 0, size, size),
        hyp = sqrt(vector.r * vector.r + vector.g * vector.g + vector.b * vector.b),
        dr = vector.r / hyp,
        dg = vector.g / hyp,
        db = vector.b / hyp,
        distance = vector.distance(average) * .4;
    
    for(var i = 0; i < data.data.length; i += 4) {
      copyData.data[i]  = data.data[i]    + (dr * distance).toInt();
      copyData.data[i+1] = data.data[i+1] + (dg * distance).toInt();
      copyData.data[i+2] = data.data[i+2] + (db * distance).toInt();
      copyData.data[i+3] = 255;
    }
    return copyData;
  }
}