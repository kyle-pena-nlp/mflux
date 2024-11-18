import time
from mflux import Config, Flux1, ModelConfig, StopImageGenerationException
from flask import Flask, request, jsonify, send_file
from io import BytesIO
from PIL import Image
from argparse import ArgumentParser, Namespace
from waitress import serve
import json

app = Flask(__name__)


@app.route('/imagePrompt', methods=['GET'])
def image_prompt():
    # Extract the 'prompt' from the request JSON and query string parameters
    json_args = request.get_json(force=True, silent=True) or {}
    query_args = request.args.to_dict()
    # Combine both dictionaries, giving precedence to JSON parameters
    args = Namespace(**{**query_args, **json_args})
    # Validate the combined arguments
    args = validate_args(args)
    # Generate the image
    image = generate(args)

    # Save the image to a BytesIO object
    img_io = BytesIO()
    image.save(img_io, 'PNG')
    img_io.seek(0)

    # Return the image as a response
    return send_file(img_io, mimetype='image/png')

def generate(args : any) -> Image:
    
    flux = Flux1(
        model_config=ModelConfig.from_alias('dev'),
        quantize=8
    )

    try:
        # Generate an image
        image = flux.generate_image(
            seed=args.seed,
            prompt=args.prompt,
            config=Config(
                num_inference_steps=args.steps,
                height=args.height,
                width=args.width
            ),
        )

        # Save the image
        pil_img = image.image
        return pil_img
        #image.save(path=args.output, export_json_metadata=args.metadata)


    except StopImageGenerationException as stop_exc:
        print(stop_exc)    

def validate_args(args):
    required_keys = {'seed':int, 'prompt':str, 'steps':int, 'height':int, 'width': int}
    for key in required_keys:
        if key not in args:
            raise Exception(f"Missing property in JSON request body: {key}")
        setattr(args,key, required_keys[key](getattr(args,key)))
    return args

if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument("--port", type = int, default = 3000)
    cli_args = parser.parse_args()
    serve(app, port = cli_args.port)
