import asyncio, uuid, json
from argparse import ArgumentParser
from io import BytesIO
from typing import Dict
from PIL import Image
from mflux import Config, Flux1, ModelConfig, StopImageGenerationException
import nats
from nats.errors import ConnectionClosedError, NoServersError


async def main(cli_args):

    id = uuid.uuid4()
    print(f"Worker {id} spun up...")

    # Abe - this will be the port that the NATs server runs on if you spun up the server with `docker compose  up`
    nc = await nats.connect(cli_args.nats_server_address)

    async def generate_and_send_image(msg):
        
        # Deserialize message
        request = json.loads(msg.data.decode())
        print(f"Worker {id} got img_gen prompt: {request['prompt']}")
        
        # Generate an image conforming to the request
        image = generate_image(request)

        # If image generation failed, early out with a header indicating failure and zero length bytes string
        if image is None:
            await nc.publish(msg.reply, b'', headers = Dict(success='false'))
            return
        
        # Turn it into bytes
        img_io = BytesIO()
        image.save(img_io, 'PNG')
        img_io.seek(0)

        # Send image as bytes along with a mimetype header
        headers = Dict(mimetype='image/png',success='true')
        await nc.publish(msg.reply, img_io.read(), headers=headers)

    # Respond to requests for image generation in the queue named 'workers'
    sub = await nc.subscribe("img_gen", "workers", generate_and_send_image)

    # Wait until the user closes it down
    input("Press [Enter] to close worker and exit")

    # Remove interest in subscription
    await sub.unsubscribe()

    # Terminate connection, waiting for all current processing to complete
    await nc.drain()


def generate_image(request : Dict[str,any]) -> Image:

    flux = Flux1(
        model_config=ModelConfig.from_alias('schnell'),
        quantize=8
    )

    try:
        # Generate an image
        image = flux.generate_image(
            seed=request["seed"],
            prompt=request["prompt"],
            config=Config(
                num_inference_steps=request["num_steps"],
                height=request["height"],
                width=request["width"]
            )
        )

        # Save the image
        pil_img = image.image
        return pil_img
    except:
        return None

if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument("--nats_server_address", type = str, default = "nats://localhost:4223")
    cli_args = parser.parse_args()
    asyncio.run(main(cli_args))