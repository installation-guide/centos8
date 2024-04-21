# Install Tensorflow on nvidia GPU

## 1. Setup environment for Tensorflow using CPU

## 2. Setup environment for Tensorflow using nvidia on WSL2 Ubuntu

* Install Nvidia Drivers on Window

> RTX 3060 Driver: 552.12-desktop-win10-win11-64bit-international-dch-whql.exe
> Reboot PC

* Install Nvidia Driver on WSL2 Ubuntu

[Download Nvidia Driver](www.nvidia.com/drivers)
[cuda_11.8_installation_on_Ubuntu_22.04](https://gist.github.com/MihailCosmin/affa6b1b71b43787e9228c25fe15aeba)
[how-to-install-cuda-11-4-cudnn-8-2-opencv-4-5-on-ubuntu-20-04](https://medium.com/@pydoni/how-to-install-cuda-11-4-cudnn-8-2-opencv-4-5-on-ubuntu-20-04-65c4aa415a7b)
[cuDNN Archive](https://developer.nvidia.com/rdp/cudnn-archive)
* Uninstall Nvidia Cuda Old version

```bash
sudo apt-get --purge remove "*cublas*" "*cufft*" "*curand*" "*cusolver*" "*cusparse*" "*npp*" "*nvjpeg*" "cuda*" "nsight*"
sudo apt-get --purge remove "*nvidia*"
sudo apt-get autoremove
sudo apt-get autoclean
sudo rm -rf /usr/local/cuda*
```

* Get Cuda Version

```bash
nvidia-smi
## Tue Apr  9 22:10:46 2024
## +-----------------------------------------------------------------------------+
## | NVIDIA-SMI 520.61.03    Driver Version: 522.06       CUDA Version: 11.8     |
## |-------------------------------+----------------------+----------------------+
## | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
## | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
## |                               |                      |               MIG M. |
## |===============================+======================+======================|
## |   0  NVIDIA GeForce ...  On   | 00000000:01:00.0  On |                  N/A |
## |  0%   42C    P5    20W / 170W |   1301MiB / 12288MiB |      1%      Default |
## |                               |                      |                  N/A |
## +-------------------------------+----------------------+----------------------+
## 
## +-----------------------------------------------------------------------------+
## | Processes:                                                                  |
## |  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
## |        ID   ID                                                   Usage      |
## |=============================================================================|
## |    0   N/A  N/A        23      G   /Xwayland                       N/A      |
## +-----------------------------------------------------------------------------+

### CUDA Version: 11.8
```

* Install Nvidia Cuda-11.8 
```bash
sudo apt update && sudo apt upgrade -y
# install other import packages
sudo apt install -y g++ freeglut3-dev build-essential libx11-dev libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev

# Ubuntu 20.04
#sudo apt install build-essential
#sudo apt -y install gcc-8 g++-8 gcc-9 g++-9
sudo apt-key del 7fa2af80
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin
sudo mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/3bf863cc.pub
sudo add-apt-repository 'deb https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/ /'
sudo apt-get update
 # installing CUDA-11.8
sudo apt install cuda-11-8 -y
# check
/usr/local/cuda/bin/nvidia-smi
/usr/local/cuda/bin/nvcc --version
##
echo 'export PATH=/usr/local/cuda-11.8/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-11.8/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

cd ~/setups
wget https://developer.download.nvidia.com/compute/redist/cudnn/v8.6.0/local_installers/11.8/cudnn-local-repo-ubuntu2004-8.6.0.163_1.0-1_amd64.deb
sudo dpkg -i cudnn-local-repo-ubuntu2004-8.6.0.163_1.0-1_amd64.deb
sudo cp /var/cudnn-local-repo-ubuntu2004-8.6.0.163/cudnn-local-B0FE0A41-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get install -y libcudnn8=8.6.0.163-1+cuda11.8 libcudnn8-dev=8.6.0.163-1+cuda11.8
# Finally, to verify the installation, check
nvidia-smi
nvcc -V

sudo apt install python3-numba
numba -s
```

* Install Miniconda

```bash
sudo mkdir -p /opt/miniconda3
sudo chown -R datascient:datascient /opt/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/setups/miniconda.sh
bash ~/setups/miniconda.sh -b -u -p /opt/miniconda3
rm -rf ~/setups/miniconda.sh

/opt/miniconda3/bin/conda init bash
```

* Create Python Environment with Cuda
```bash
conda env list
conda env remove -n py39tf2gpu 
conda create -n py39tf2gpu python=3.9 -y
conda activate py39tf2gpu 
#conda install -y -c conda-forge cudatoolkit=11.8 cudnn=8.6.0.163
#python3 -m pip install tensorflow[and-cuda]
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_PREFIX/lib/
python3 -m pip install tensorflow[and-cuda]==2.14
# Verify the installation:
python3 -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```
[Tensorflow GPU version](https://www.tensorflow.org/install/source#gpu)

Version	            Python version	Compiler	    Build tools	    cuDNN	CUDA

tensorflow-2.16.1	3.9-3.12	    Clang 17.0.6	Bazel 6.5.0	    8.9	    12.3

tensorflow-2.15.0	3.9-3.11	    Clang 16.0.0	Bazel 6.1.0	    8.9	    12.2

tensorflow-2.14.0	3.9-3.11	    Clang 16.0.0	Bazel 6.1.0	    8.7	    11.8
* 
```bash
export SRC_HOME=~/Dev/tfbenchmark; \
[ ! -d $SRC_HOME ] && { mkdir -p $SRC_HOME; }; \
cd $SRC_HOME; \
tee tfben_TrainingDigitClassifier_GPU.py > /dev/null <<'EOF'
import tensorflow as tf
from tensorflow import keras
import numpy as np
import matplotlib.pyplot as plt


(X_train, y_train), (X_test, y_test) = keras.datasets.cifar10.load_data()
# scaling image values between 0-1
X_train_scaled = X_train/255
X_test_scaled = X_test/255
# one hot encoding labels
y_train_encoded = keras.utils.to_categorical(y_train, num_classes = 10, dtype = 'float32')
y_test_encoded = keras.utils.to_categorical(y_test, num_classes = 10, dtype = 'float32')
def get_model():
    model = keras.Sequential([
        keras.layers.Flatten(input_shape=(32,32,3)),
        keras.layers.Dense(3000, activation='relu'),
        keras.layers.Dense(1000, activation='relu'),
        keras.layers.Dense(10, activation='sigmoid')    
    ])
    model.compile(optimizer='SGD',
              loss='categorical_crossentropy',
              metrics=['accuracy'])
    return model

# GPU
with tf.device('/GPU:0'):
    model_gpu = get_model()
    model_gpu.fit(X_train_scaled, y_train_encoded, epochs = 10)
EOF

export SRC_HOME=~/Dev/tfbenchmark; time python ${SRC_HOME}/tfben_TrainingDigitClassifier_GPU.py
## Ryzen 5600G GPU, GigaByte RTX 3060 OC 12GB, on WSL2 Ubuntu 22.04
#real    1m28.896s
#user    1m15.004s
#real    6m41.210s
### Ryzen 5600G GPU, GigaByte RTX 3060 OC 12GB, on Ubuntu 22.04
# epoch 5s 3ms/step - loss: 1.8131
#real    0m46.075s
#user    0m46.054s
#sys     0m5.228s
```