---
layout: post
title:  "Traffic light detection by yolov3"
categories: [ Autopilot ]
image: https://pjreddie.com/media/image/Screen_Shot_2018-03-24_at_10.48.42_PM.png
key:  20190909
author: lyf
tags: [sticky]
---

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611143738.jpg)


>You only look once (YOLO) is a state-of-the-art, real-time object detection system. On a Pascal Titan X it processes images at 30 FPS and has a mAP of 57.9% on COCO test-dev.

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611143806.png)


1. [Yolo](https://pjreddie.com/darknet/yolo/)使用c和cuda实现，体积小，代码量相对不大，适合于结合论文和代码去研究其神经网络的结构和原理；
2. 已经实现了直接接入摄像头进行实时目标检测功能；
3. 参考上图，yolo的性能好。

### 任务目标

实时对红绿灯的**状态**进行检测，由于黄灯数据量较小，目前暂未对黄灯状态进行训练，目前共包括以下状态，

```
green
greenleft
greenstraight
red
redleft
redstraight
```

### 数据采集
首先，在淘宝上买了一个5-50mm变焦的USB免驱工业摄像头，然后借助ROS(Robot Operating System)中的package进行图像的采集，

 1. 摄像头驱动
http://wiki.ros.org/usb_cam。
借助了usb_cam package，下载代码后编译运行，
```
    roslaunch usb_cam usb_cam-test.launch
```
 2. 自动采集图像
借助了[image_view](http://wiki.ros.org/image_view) package，
其中一些参数可以自己设置，例如图片名，帧率等。

```
rosrun image_view extract_images _sec_per_frame:=0.5 _filename_format:=trafficlight_%04d.jpg image:=/usb_cam/image_raw
```
### 数据标注
使用的软件为[labelImg](https://github.com/tzutalin/labelImg)，首先将predefined_classes.txt修改为红灯和绿灯的状态，
```
green
greenleft
greenstraight
red
redleft
redstraight
```
切换labelImg输出为yolo，

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611143835.png)



进行数据标注，

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611143901.png)


保存，生成的标注文件为frame1405.txt，内容如下，

```
1 0.030078 0.358854 0.022656 0.030208
2 0.105859 0.357812 0.025781 0.034375
2 0.256250 0.353125 0.026562 0.035417
```

待数据标注完成后(**每种class的图片大概2000张左右，包括不同角度，天气等环境**)，接下来进行训练。

### 模型训练
#### yolo代码编译

```
git clone https://github.com/pjreddie/darknet
```

修改makefile，我使用的显卡是gtx 1060，6G显存(训练最好选择显存>=6G的显卡)，cuda 10.0，计算能力6.1。

```
GPU=1
CUDNN=1
OPENCV=1
ARCH=-gencode arch=compute_61,code=[sm_61,compute_61]
```

修改完成后，

```
make
```

#### 预训练模型下载
 https://pjreddie.com/media/files/yolov3.weights
#### yolov3.cfg参数修改

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611143952.png)


yolov3在feature extractor时使用了新的darknet-53网络，具体的论文可以参考[这里](https://pjreddie.com/media/files/papers/YOLOv3.pdf)。

**修改yolov3.cfg，**

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611144012.png)


关于batch size可以根据训练时所使用的硬件进行调整，

 - 第6行，说明每个step我们将使用64张图片进行训练；
 - 第7行，batch将会被分成16个小的组，64/16，用来减小显存的需求；

如果在训练中提示显存不够，可以尝试增加subdivisions值，例如，
```
batch=64
subdivisions=32
```
更甚，
```
batch=64
subdivisions=64
```
关于**最大训练步数**，一般设置为classes*2000，而steps设置为上述值的80%和90%。训练时classes为6，则值如下所示，

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611144040.png)



关于图片的大小，一般不用去修改，yolo中会根据其神经网络进行调整缩放,

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611144104.png)

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611144108.png)





关于**classes and filters**，class和filter的设置可以参考论文中的公式，

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611144141.png)



例如，我的classes为6,则yolo层上一层的filters应设置为3*(4+1+6)=33(**只需修改所有yolo层的classes和该层上面一层的卷积层**)。

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611144204.png)



#### 修改voc.data

根据自己的实际路径去修改，

```
    classes= 6
    train  = /your_path/train.txt
    valid  = /your_path/test.txt
    names = /your_path/voc.names
    backup = backup
```

#### 修改voc.names

**必须和标注时所使用的类别文件中的内容相同，**

```
green
greenleft
greenstraight
red
redleft
redstraight
```

#### 开始训练

```
./darknet detector train cfg/voc.data cfg/yolov3.cfg darknet53.conv.74
```

### 训练结果测试

#### 训练结果

在训练过程中，每4个epoch计算一次mAP，训练集和测试集的数量如下所示，

```
mAP (mean average precisions) calculation for each 4 Epochs (1 Epoch= images_in_train_txt /batch iteration)
dataset_train=3237
dataset_test=323
```

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611144228.png)



上图横坐标为训练的迭代次数，纵坐标为mAP值和loss值，**在4000步左右时，loss已经趋于稳定，为0.2746。mAP值已经达到90%以上**。
下图为训练完成时的结果，**mAP值已经达到98%**。

![](https://gitpage-images.oss-cn-beijing.aliyuncs.com/img/20190611144249.png)


#### 红绿灯实时检测

Yolo可以直接接入摄像头进行目标实时检测，命令如下，训练完成后的模型为trained.weights，

    ./darknet detector demo cfg/voc.data cfg/yolov3.cfg trained.weights

如果你的测试电脑上有多个camera(我的笔记本还有个默认的摄像头,yolo 默认device是0)，可以利用`-c <num>`参数去选取，

    ./darknet detector demo cfg/voc.data cfg/yolov3.cfg trained.weights -c 1

此外，你还可以利用录制的视频去做检测，命令如下，

    ./darknet detector demo cfg/voc.data cfg/yolov3.cfg trained.weights <video file>

实时红绿灯检测视频如下所示，

<div>{%- include extensions/bilibili.html id='54980222' -%}</div>