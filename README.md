# Photo Draw

![Demo](https://user-images.githubusercontent.com/43227465/165872870-76e0e191-ed2f-44eb-885c-8c9a11336079.gif)


My app for the 2022 Swift Student Challenge.

'Photo Draw' is a neat little drawing app with an amazing trick up its sleeve. It allows you to convert images with handwriting or line drawings to vector paths. These paths can then be manipulated exactly like they were drawn directly on your device. It's perfect for those who prefer the feel of paper or students who want to digitize what's on the board in the classroom!

## Why did I make this app?

There's something to be said for the focussed task of writing with pen and paper. You can't get distracted by notifications in a Muji notebook like you can when writing on an iPad. However, the digital writing and drawing experience can be better at times. With digital ink, if you want to move something to make more space, you can simply select and move it. And if you want to change the color, you can pick a new one. 

For years I wished there was a way to convert my notes on paper to digital. Better yet if I could easily take a photo of the chalkboard in class and have all of the math written there editable in my notes. So I decided to make an app that can do just that!

### Disclaimers

The image path finding algorithm I implemented uses the process outlined in the paper [A complete hand-drawn sketch vectorization framework](https://arxiv.org/pdf/1802.05902.pdf) by L. Donati, S. Cesano, and A. Prati.

**This app was tested with Xcode 13.3 and should be compiled using Xcode rather than Swift Playgrounds 4.**

Test on an iPad for the best experience :)

### Overview of Technologies

My drawing app is comprised mostly of SwiftUI with some UIKit views sprinkled in. The navigation uses SwiftUI that is updated with changes to the view model. The UIKit views enable system integrations like VisionKit's document scanner, PhotosUI's photo picker, and PencilKit's canvas. These views still update in a reactive way by subscribing to changes from Combine publishers so they are always in sync with the model.

PencilKit is the foundation for displaying strokes on the canvas. Since PencilKit now exposes the strokes in a drawing, I am able to programmatically add new vector paths. The heart of my app is the ImagePathConverter that generates the new strokes that are added to the drawing. I create image kernels using MetalKit that execute on the GPU, modifying the image to generate a final image that for any pixel determines if it is or is not part of a stroke. These kernels are written in Metal Shading Language.

I used Swift Concurrency to process image vector conversions in the background without blocking the main thread. By having the work done in a Task, the image can be placed and rendered using Core Graphics as we await its converted strokes. Grand Central Dispatch let me perform parallel loops. These loops sped up generating the paths by allowing them be created across multiple threads simultaneously when the data was independent.
With the finished product of having images converted to strokes, I'm really proud of what I was able to bring together using Apple's Frameworks.



