FROM pytorch/pytorch:latest
RUN pip install torchserve torch-model-archiver
WORKDIR /workspace
ADD model_trace.py .
ADD sample.jpg .
RUN python3 model_trace.py
RUN torch-model-archiver --model-name resnet18 \
                         --version 1.0 \ 
                         --serialized-file scripted_model.pt \
                         --handler image_classifier \
                         --export-path . \
                         -f 
CMD ["torchserve", "--start", "--ncs", "--model-store", ".", "--models", "resnet18.mar"]