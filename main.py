from cortex_client import CortexClient


def main():

    cortex = CortexClient()

    try:

        cortex.connect()

        cortex.request_access()

        cortex.authorize()

        cortex.query_headsets()

        cortex.create_session()

        cortex.subscribe_eeg()

        cortex.listen()

    finally:

        cortex.disconnect()


if __name__ == "__main__":
    main()