# Install PyTorch on WSL2


* Install Nvidia Drivers on Window

> RTX 3060 Driver: 552.12-desktop-win10-win11-64bit-international-dch-whql.exe

* Install Nvidia Cuda-11.8, cudnn8

* Install PyTorch on WLS2
```bash
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

python3 -c "import torch; print(torch.cuda.is_available())"
```

## Reference:
* https://joelognn.medium.com/installing-wsl2-pytorch-and-cuda-on-windows-11-65a739158d76
