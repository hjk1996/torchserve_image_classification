from torchvision.models import resnet18, ResNet18_Weights
from torchvision.transforms import Resize
from torchvision.io import read_image
import torch

if __name__ == "__main__":
    weights = ResNet18_Weights.DEFAULT
    resize_transform = Resize((224, 224))
    model = resnet18(weights=weights)
    model.eval()
    img = read_image("sample.jpg")
    resized_img = resize_transform(img)
    resized_img = resized_img.unsqueeze(0)
    traced_model = torch.jit.trace(model, resized_img.float())
    traced_model.save("scripted_model.pt")
